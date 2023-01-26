-------------------------------------------------------------------------------
--                                                                           --
--                              Wee Noise Maker                              --
--                                                                           --
--                  Copyright (C) 2016-2017 Fabien Chouteau                  --
--                                                                           --
--    Wee Noise Maker is free software: you can redistribute it and/or       --
--    modify it under the terms of the GNU General Public License as         --
--    published by the Free Software Foundation, either version 3 of the     --
--    License, or (at your option) any later version.                        --
--                                                                           --
--    Wee Noise Maker is distributed in the hope that it will be useful,     --
--    but WITHOUT ANY WARRANTY; without even the implied warranty of         --
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU       --
--    General Public License for more details.                               --
--                                                                           --
--    You should have received a copy of the GNU General Public License      --
--    along with We Noise Maker. If not, see <http://www.gnu.org/licenses/>. --
--                                                                           --
-------------------------------------------------------------------------------

with HAL; use HAL;
with Interfaces; use Interfaces;
with WNM.Sample_Stream;          use WNM.Sample_Stream;
with WNM.Sample_Library;         use WNM.Sample_Library;
with WNM.Coproc;
with MIDI;

with WNM.Speech;

with Tresses; use Tresses;
with Tresses.Drums.Kick;
with Tresses.Drums.Clap;
with Tresses.Drums.Cymbal;
with Tresses.Voices.Macro;
with Tresses.Macro;
with Tresses.Interfaces;
with Tresses.FX.Delay_Line;
with Tresses.FX.Overdrive;
with Tresses.Filters.SVF;
with Tresses.LFO;

package body WNM.Synth is

   type FX_Kind is (Bypass, Overdrive, Delayline, Filter);

   TK   : aliased Tresses.Drums.Kick.Instance;
   TS   : aliased Tresses.Drums.Clap.Instance;
   TC   : aliased Tresses.Drums.Cymbal.Instance;
   Lead : aliased Tresses.Voices.Macro.Instance;
   Bass : aliased Tresses.Voices.Macro.Instance;

   DLL : Tresses.FX.Delay_Line.Instance
     (Unsigned_16 (MIDI.MIDI_Data'Last) * 100 + 1);
   DLR : Tresses.FX.Delay_Line.Instance
     (Unsigned_16 (MIDI.MIDI_Data'Last) * 100 + 1);

   FL : Tresses.Filters.SVF.Instance;
   FR : Tresses.Filters.SVF.Instance;

   Drive_Amount : Tresses.Param_Range := 0;
   Delay_Time : Tresses.Param_Range := 0;
   Delay_Feedback : Tresses.Param_Range := 0;
   Filter_Mode : Tresses.Filters.SVF.Mode_Kind :=
     Tresses.Filters.SVF.Mode_Kind'First;
   Filter_Cutoff : Tresses.Param_Range := 20_000;
   Filter_Resonance : Tresses.Param_Range := 0;

   subtype Voice_Class is Tresses.Interfaces.Four_Params_Voice'Class;
   type Voice_Access is access all Voice_Class;

   function Lead_Engines (V : MIDI.MIDI_Data) return Tresses.Synth_Engines
   is (case V is
          when 0 => Tresses.Voice_Saw_Swarm,
          when 1 => Tresses.Voice_Acid,
          when 2 => Tresses.Voice_Analog_Buzz,
          when 3 => Tresses.Voice_Analog_Morph,
          when 4 => Tresses.Voice_FM2OP,
          when 5 => Tresses.Voice_Sand,
          when others => Tresses.Voice_Plucked);

   subtype Synth_Channels
     is MIDI.MIDI_Channel range Sample_Channel .. Bass_Channel;

   subtype Tresses_Channels
     is MIDI.MIDI_Channel range Kick_Channel .. Bass_Channel;

   Synth_Voices : constant array (Tresses_Channels) of
     Voice_Access :=
       (Kick_Channel   => TK'Access,
        Snare_Channel  => TS'Access,
        Cymbal_Channel => TC'Access,
        Lead_Channel   => Lead'Access,
        Bass_Channel   => Bass'Access);

   LFO_Targets : array (Synth_Channels) of MIDI.MIDI_Data :=
     (others => Voice_Pan_CC);
     --  (others => MIDI.MIDI_Data'Last);

   LFOs : array (Synth_Channels) of Tresses.LFO.Instance;
   LFO_Values : array (Synth_Channels) of Tresses.Param_Range;

   type Voice_Parameters_Array is array (Synth_Channels, LFO_Compatible_CC)
     of Tresses.Param_Range;
   In_Voice_Parameters : Voice_Parameters_Array := (others => (others => 0));
   Out_Voice_Parameters : Voice_Parameters_Array := (others => (others => 0));

   Last_Key : array (MIDI.MIDI_Channel) of MIDI.MIDI_Key := (others => 0);
   FX_Send : array (MIDI.MIDI_Channel) of FX_Kind := (others => Bypass);

   Pan_For_Chan : array (MIDI.MIDI_Channel) of WNM_HAL.Audio_Pan :=
     (others => WNM_HAL.Init_Pan);

   Volume_For_Chan : array (MIDI.MIDI_Channel) of WNM_HAL.Audio_Volume :=
     (others => WNM_HAL.Init_Volume);

   Selected_Sample : MIDI.MIDI_Data := 0;

   Recording_Source : Rec_Source;
   Recording_Size   : Natural;

   Passthrough : Audio_Input_Kind := Line_In;

   Next_Start : WNM.Time.Time_Microseconds := WNM.Time.Time_Microseconds'First;
   Glob_Sample_Clock : Sample_Time := 0 with Volatile;

   procedure Process_Coproc_Events;

   --------------
   -- To_Param --
   --------------

   function To_Param (V : MIDI.MIDI_Data)
                      return Tresses.Param_Range
   is
   begin
      return Param_Range (V) *
        (Param_Range'Last / Param_Range (MIDI.MIDI_Data'Last));
   end To_Param;

   ---------------
   -- To_Volume --
   ---------------

   function To_Volume (V : Tresses.Param_Range)
                       return WNM_HAL.Audio_Volume
   is
   begin
      return WNM_HAL.Audio_Volume (V / 328);
   end To_Volume;

   ------------
   -- To_Pan --
   ------------

   function To_Pan (V : Tresses.Param_Range)
                    return WNM_HAL.Audio_Pan
   is
   begin
      return WNM_HAL.Audio_Pan (V / 328);
   end To_Pan;

   ------------------
   -- Sample_Clock --
   ------------------

   function Sample_Clock return Sample_Time
   is (Glob_Sample_Clock);

   ----------
   -- Trig --
   ----------

   procedure Trig (Track  : Sample_Stream.Stream_Track;
                   Sample : Sample_Library.Valid_Sample_Index)
   is
   begin
      Start (Track       => Track,
             Sample      => Sample,
             Start_Point => Sample_Library.Sample_Point_Index'First,
             End_Point   => Sample_Library.Sample_Point_Index'Last,
             Looping     => False);
   end Trig;

   ---------------------------
   -- Process_Coproc_Events --
   ---------------------------

   procedure Process_Coproc_Events is
      use MIDI;

      Msg : WNM.Coproc.Message;
      Success : Boolean;
   begin
      loop
         WNM.Coproc.Pop (Msg, Success);

         exit when not Success;

         case Msg.Kind is

            when WNM.Coproc.MIDI_Event =>

               --  Ada.Text_IO.Put_Line
               --    (Clock'Img & " - " &
               --     MIDI.Img (Msg.MIDI_Evt));

               if Msg.MIDI_Evt.Chan = Sample_Channel then
                  case Msg.MIDI_Evt.Kind is
                     when MIDI.Note_On =>
                        WNM.Sample_Stream.Start
                          (1,
                           Sample_Library.Sample_Index (Selected_Sample) + 1,
                           Sample_Library.Sample_Point_Index'First,
                           Sample_Library.Sample_Point_Index'Last,
                           False);

                        Last_Key (Msg.MIDI_Evt.Chan) := Msg.MIDI_Evt.Key;

                     when MIDI.Note_Off =>

                        if Last_Key (Msg.MIDI_Evt.Chan) = Msg.MIDI_Evt.Key
                        then
                           Last_Key (Msg.MIDI_Evt.Chan) := 0;
                        end if;

                     when MIDI.Continous_Controller =>
                        case Msg.MIDI_Evt.Controller is
                           when 0 =>
                              Selected_Sample :=
                                Msg.MIDI_Evt.Controller_Value;
                           when others =>
                              null;
                        end case;

                     when others =>
                        null;
                  end case;

               elsif Msg.MIDI_Evt.Chan = Speech_Channel then
                  case Msg.MIDI_Evt.Kind is
                     when MIDI.Note_On =>
                        WNM.Speech.Start (Msg.MIDI_Evt.Key);

                        Last_Key (Msg.MIDI_Evt.Chan) := Msg.MIDI_Evt.Key;

                     when MIDI.Note_Off =>

                        if Last_Key (Msg.MIDI_Evt.Chan) = Msg.MIDI_Evt.Key
                        then
                           WNM.Speech.Stop;
                           Last_Key (Msg.MIDI_Evt.Chan) := 0;
                        end if;

                     when MIDI.Continous_Controller =>
                        case Msg.MIDI_Evt.Controller is
                           when 0 =>
                              WNM.Speech.Set_Word
                                (WNM.Speech.Word
                                   (Natural
                                        (Msg.MIDI_Evt.Controller_Value + 1)));
                           when 1 =>
                              WNM.Speech.Set_Stretch
                                (Msg.MIDI_Evt.Controller_Value);
                           when others =>
                              null;
                        end case;

                     when others =>
                        null;
                  end case;

               elsif Msg.MIDI_Evt.Chan = FX_Settings_Channel then
                  case Msg.MIDI_Evt.Kind is
                     when MIDI.Continous_Controller =>
                        case Msg.MIDI_Evt.Controller is
                           when FX_Drive_Amount_CC =>
                              Drive_Amount :=
                                To_Param
                                  (Msg.MIDI_Evt.Controller_Value);

                           when FX_Delay_Time_CC =>
                              Delay_Time :=
                                To_Param
                                  (Msg.MIDI_Evt.Controller_Value);

                           when FX_Delay_Feedback_CC =>
                              Delay_Feedback :=
                                To_Param
                                  (Msg.MIDI_Evt.Controller_Value);

                           when FX_Filter_Mode_CC =>

                              declare
                                 use Tresses.Filters.SVF;
                                 Val : constant MIDI_Data :=
                                   Msg.MIDI_Evt.Controller_Value;
                              begin
                                 if Val <= Mode_Kind'Pos (Mode_Kind'Last)
                                 then
                                    Filter_Mode := Mode_Kind'Val (Val);
                                 end if;
                              end;

                           when FX_Filter_Cutoff_CC =>
                              Filter_Cutoff :=
                                To_Param
                                  (Msg.MIDI_Evt.Controller_Value);

                           when FX_Filter_Reso_CC =>
                              Filter_Resonance :=
                                To_Param
                                  (Msg.MIDI_Evt.Controller_Value);

                           when others => null;
                        end case;
                     when others => null;
                  end case;

               elsif Msg.MIDI_Evt.Chan in Synth_Voices'Range then
                  declare
                     Voice : Voice_Class renames
                       Synth_Voices (Msg.MIDI_Evt.Chan).all;
                  begin
                     case Msg.MIDI_Evt.Kind is
                     when MIDI.Note_On =>
                        Voice.Set_Pitch (Tresses.MIDI_Pitch
                                         (Standard.MIDI.MIDI_UInt8
                                            (Msg.MIDI_Evt.Key)));

                        Voice.Note_On (To_Param
                                       (Msg.MIDI_Evt.Velocity));

                        Last_Key (Msg.MIDI_Evt.Chan) := Msg.MIDI_Evt.Key;

                     when MIDI.Note_Off =>

                        if Last_Key (Msg.MIDI_Evt.Chan) = Msg.MIDI_Evt.Key
                        then
                           --  Only apply note_off if it matches the last
                           --  played key.
                           Voice.Note_Off;
                           Last_Key (Msg.MIDI_Evt.Chan) := 0;
                        end if;

                     when MIDI.Continous_Controller =>
                        case Msg.MIDI_Evt.Controller is
                           when LFO_Compatible_CC =>
                              In_Voice_Parameters (Msg.MIDI_Evt.Chan,
                                                   Msg.MIDI_Evt.Controller)
                                := To_Param
                                  (Msg.MIDI_Evt.Controller_Value);

                           when Voice_Engine_CC =>

                              case Msg.MIDI_Evt.Chan is
                              when Lead_Channel =>
                                 Lead.Set_Engine
                                   (Lead_Engines
                                      (Msg.MIDI_Evt.Controller_Value));
                              when Bass_Channel =>
                                 Bass.Set_Engine
                                   (Lead_Engines
                                      (Msg.MIDI_Evt.Controller_Value));
                              when others =>
                                 null;
                              end case;

                           when Voice_FX_CC =>
                              FX_Send (Msg.MIDI_Evt.Chan) :=
                                (case Msg.MIDI_Evt.Controller_Value is
                                    when FX_Select_Bypass => Bypass,
                                    when FX_Select_Overdrive => Overdrive,
                                    when FX_Select_Delayline => Delayline,
                                    when FX_Select_Filter => Filter,
                                    when others => Bypass);

                           when Voice_LFO_Rate_CC =>
                              LFOs (Msg.MIDI_Evt.Chan).Set_Rate
                                (To_Param (Msg.MIDI_Evt.Controller_Value),
                                 WNM_Configuration.Audio.Samples_Per_Buffer);

                           when Voice_LFO_Amp_CC =>
                              LFOs (Msg.MIDI_Evt.Chan).Set_Amplitude
                                (To_Param
                                   (Msg.MIDI_Evt.Controller_Value));

                           when Voice_LFO_Target_CC =>
                              LFO_Targets (Msg.MIDI_Evt.Chan) :=
                                Msg.MIDI_Evt.Controller_Value;

                           when others =>
                              null;
                        end case;
                     when others =>
                        null;
                     end case;
                  end;
               end if;
         end case;
      end loop;
   end Process_Coproc_Events;

   ------------
   -- Update --
   ------------

   function Update return WNM.Time.Time_Microseconds is
      Now : constant WNM.Time.Time_Microseconds := WNM.Time.Clock;
   begin
      if Now >= Next_Start then
         Next_Start := Next_Start + 0;

         Process_Coproc_Events;

         --  Generate_Audio;
      end if;

      return Next_Start;
   end Update;

   -----------------
   -- Next_Points --
   -----------------

   procedure Next_Points (Output : out WNM_HAL.Stereo_Buffer;
                          Input  :     WNM_HAL.Stereo_Buffer)
   is
      Send_L_Buffers : array (FX_Kind) of WNM_HAL.Mono_Buffer :=
        (others => (others => 0));
      Send_R_Buffers : array (FX_Kind) of WNM_HAL.Mono_Buffer :=
        (others => (others => 0));
      --  Why allocated on the stack? RP2040 has faster "scratch mem" for
      --  stacks.

      Buffer, Aux_Buffer : WNM_HAL.Mono_Buffer;

      -------------
      -- Add_Sat --
      -------------

      function Add_Sat (A, B : Param_Range) return Param_Range is
         Result : constant U16 := U16 (A) + U16 (B);
      begin
         if Result > U16 (Param_Range'Last) then
            return Param_Range'Last;
         else
            return Param_Range (Result);
         end if;
      end Add_Sat;

   begin

      --  Take input params
      Out_Voice_Parameters := In_Voice_Parameters;

      --  Compute LFOs
      for Chan in LFOs'Range loop
         LFO_Values (Chan) := LFOs (Chan).Render;
      end loop;

      --  Apply LFOs
      for Chan in Tresses_Channels loop
         if LFO_Targets (Chan) in LFO_Compatible_CC then
            Out_Voice_Parameters (Chan, LFO_Targets (Chan)) :=
              Add_Sat (Out_Voice_Parameters (Chan, LFO_Targets (Chan)),
                       LFO_Values (Chan));
         end if;
      end loop;

      --  Set params
      for Chan in Tresses_Channels loop
         Synth_Voices (Chan).Set_Param
           (1, Out_Voice_Parameters (Chan, Voice_Param_1_CC));
         Synth_Voices (Chan).Set_Param
           (2, Out_Voice_Parameters (Chan, Voice_Param_2_CC));
         Synth_Voices (Chan).Set_Param
           (3, Out_Voice_Parameters (Chan, Voice_Param_3_CC));
         Synth_Voices (Chan).Set_Param
           (4, Out_Voice_Parameters (Chan, Voice_Param_4_CC));

         Pan_For_Chan (Chan) :=
           To_Pan (Out_Voice_Parameters (Chan, Voice_Pan_CC));

         Volume_For_Chan (Chan) :=
           To_Volume (Out_Voice_Parameters (Chan, Voice_Volume_CC));
      end loop;

      if Passthrough /= None then
         Output := Input;
      else
         Output := (others => (0, 0));
      end if;

      --  Samples
      declare
         Success : Boolean;
      begin
         for Track in Stream_Track loop
            Next_Buffer (Track, Buffer, Success);
            if Success then
               WNM_HAL.Mix (Send_L_Buffers (FX_Send (Sample_Channel)),
                            Send_R_Buffers (FX_Send (Sample_Channel)),
                            Buffer,
                            Volume_For_Chan (Sample_Channel),
                            Pan_For_Chan (Sample_Channel));
            end if;
         end loop;
      end;

      -- Speech synth --
      declare
         Success : Boolean;
      begin
         Speech.Next_Points (Buffer, Success);

         if Success then
            WNM_HAL.Mix (Send_L_Buffers (FX_Send (Speech_Channel)),
                         Send_R_Buffers (FX_Send (Speech_Channel)),
                         Buffer,
                         Volume_For_Chan (Speech_Channel),
                         Pan_For_Chan (Speech_Channel));
         end if;
      end;

      declare
      begin
         TK.Render (Buffer);
         WNM_HAL.Mix (Send_L_Buffers (FX_Send (Kick_Channel)),
                      Send_R_Buffers (FX_Send (Kick_Channel)),
                      Input => Buffer,
                      Volume => Volume_For_Chan (Kick_Channel),
                      Pan => Pan_For_Chan (Kick_Channel));

         TS.Render (Buffer);
         WNM_HAL.Mix (Send_L_Buffers (FX_Send (Snare_Channel)),
                      Send_R_Buffers (FX_Send (Snare_Channel)),
                      Input => Buffer,
                      Volume => Volume_For_Chan (Snare_Channel),
                      Pan => Pan_For_Chan (Snare_Channel));

         TC.Render (Buffer);
         WNM_HAL.Mix (Send_L_Buffers (FX_Send (Cymbal_Channel)),
                      Send_R_Buffers (FX_Send (Cymbal_Channel)),
                      Input => Buffer,
                      Volume => Volume_For_Chan (Cymbal_Channel),
                      Pan => Pan_For_Chan (Cymbal_Channel));

         Lead.Render (Buffer, Aux_Buffer);
         WNM_HAL.Mix (Send_L_Buffers (FX_Send (Lead_Channel)),
                      Send_R_Buffers (FX_Send (Lead_Channel)),
                      Input => Buffer,
                      Volume => Volume_For_Chan (Lead_Channel),
                      Pan => Pan_For_Chan (Lead_Channel));

         Bass.Render (Buffer, Aux_Buffer);
         WNM_HAL.Mix (Send_L_Buffers (FX_Send (Bass_Channel)),
                      Send_R_Buffers (FX_Send (Bass_Channel)),
                      Input => Buffer,
                      Volume => Volume_For_Chan (Bass_Channel),
                      Pan => Pan_For_Chan (Bass_Channel));
      end;

      declare
      begin

         --  Overdrive
         Tresses.FX.Overdrive.Process (Send_L_Buffers (Overdrive),
                                       Drive_Amount);
         Tresses.FX.Overdrive.Process (Send_R_Buffers (Overdrive),
                                       Drive_Amount);

         --  Delay
         Tresses.FX.Delay_Line.Process
           (DLL,
            Send_L_Buffers (Delayline),
            Delay_Time,
            Delay_Feedback);

         Tresses.FX.Delay_Line.Process
           (DLR,
            Send_R_Buffers (Delayline),
            Delay_Time,
            Delay_Feedback);

         --  Filter
         Tresses.Filters.SVF.Set_Frequency (FL, Filter_Cutoff);
         Tresses.Filters.SVF.Set_Frequency (FR, Filter_Cutoff);

         Tresses.Filters.SVF.Set_Resonance (FL, Filter_Resonance);
         Tresses.Filters.SVF.Set_Resonance (FR, Filter_Resonance);

         Tresses.Filters.SVF.Set_Mode (FL, Filter_Mode);
         Tresses.Filters.SVF.Set_Mode (FR, Filter_Mode);

         for Elt of Send_L_Buffers (Filter) loop
            Elt := S16 (Tresses.Filters.SVF.Process (FL, S32 (Elt)));
         end loop;

         for Elt of Send_R_Buffers (Filter) loop
            Elt := S16 (Tresses.Filters.SVF.Process (FR, S32 (Elt)));
         end loop;
      end;

      --  Final mix
      for Fx in FX_Kind loop
         WNM_HAL.Mix (Output, Send_L_Buffers (Fx), Send_R_Buffers (Fx));
      end loop;

      -- Recording --
      --  if Recording_Source /= None then
      --     declare
      --        Sample_Buf : Mono_Buffer;
      --     begin
      --        case Recording_Source is
      --           when None =>
      --              null;
      --           when Line_In =>
      --              Copy_Stereo_To_Mono (In_L, In_R, Sample_Buf);
      --           when Master_Output =>
      --              Copy_Stereo_To_Mono (Out_L, Out_R, Sample_Buf);
      --        end case;
      --
      --        Len := Write (Recording_File, Sample_Buf'Address,
      --                      Sample_Buf'Length * 2);
      --        Recording_Size := Recording_Size + Len;
      --     end;
      --  end if;

      Glob_Sample_Clock :=
        Glob_Sample_Clock + WNM_Configuration.Audio.Samples_Per_Buffer;
   end Next_Points;

   ---------------------
   -- Set_Passthrough --
   ---------------------

   procedure Set_Passthrough (Kind : Audio_Input_Kind) is
   begin
      Select_Audio_Input (Kind);
      Passthrough := Kind;
   end Set_Passthrough;

   ---------------------
   -- Get_Passthrough --
   ---------------------

   function Get_Passthrough return Audio_Input_Kind is
   begin
      return Passthrough;
   end Get_Passthrough;

   ---------------------
   -- Lead_Engine_Img --
   ---------------------

   function Lead_Engine_Img (Engine : MIDI.MIDI_Data) return String
   is (Tresses.Img (Lead_Engines (Engine)));

   ----------------------
   -- Lead_Param_Label --
   ----------------------

   function Lead_Param_Label (Engine : MIDI.MIDI_Data;
                              Id : Tresses.Param_Id)
                              return String
   is
      E : constant Tresses.Synth_Engines := Lead_Engines (Engine);
   begin
      return Tresses.Macro.Param_Label (E, Id);
   end Lead_Param_Label;

   ----------------------------
   -- Lead_Param_Short_Label --
   ----------------------------

   function Lead_Param_Short_Label (Engine : MIDI.MIDI_Data;
                                    Id : Tresses.Param_Id)
                                    return Tresses.Short_Label
   is
      E : constant Tresses.Synth_Engines := Lead_Engines (Engine);
   begin
      return Tresses.Macro.Param_Short_Label (E, Id);
   end Lead_Param_Short_Label;

   ----------------------
   -- Kick_Param_Label --
   ----------------------

   function Kick_Param_Label (Id : Tresses.Param_Id) return String
   is (Tresses.Macro.Param_Label (Tresses.Drum_Kick, Id));

   ----------------------------
   -- Kick_Param_Short_Label --
   ----------------------------

   function Kick_Param_Short_Label (Id : Tresses.Param_Id)
                                    return Tresses.Short_Label
   is (Tresses.Macro.Param_Short_Label (Tresses.Drum_Kick, Id));

   -----------------------
   -- Snare_Param_Label --
   -----------------------

   function Snare_Param_Label (Id : Tresses.Param_Id) return String
   is (Tresses.Macro.Param_Label (Tresses.Drum_Snare, Id));

   -----------------------------
   -- Snare_Param_Short_Label --
   -----------------------------

   function Snare_Param_Short_Label (Id : Tresses.Param_Id)
                                    return Tresses.Short_Label
   is (Tresses.Macro.Param_Short_Label (Tresses.Drum_Snare, Id));

   ------------------------
   -- Cymbal_Param_Label --
   ------------------------

   function Cymbal_Param_Label (Id : Tresses.Param_Id) return String
   is (Tresses.Macro.Param_Label (Tresses.Drum_Cymbal, Id));

   ------------------------------
   -- Cymbal_Param_Short_Label --
   ------------------------------

   function Cymbal_Param_Short_Label (Id : Tresses.Param_Id)
                                      return Tresses.Short_Label
   is (Tresses.Macro.Param_Short_Label (Tresses.Drum_Cymbal, Id));

   -------------------
   -- Now_Recording --
   -------------------

   function Now_Recording return Rec_Source
   is (Recording_Source);

   ---------------------
   -- Start_Recording --
   ---------------------

   procedure Start_Recording (Filename : String;
                              Source   : Rec_Source;
                              Max_Size : Positive)
   is
      pragma Unreferenced (Max_Size, Filename);
   begin
      if Recording_Source /= None then
         return;
      end if;

      Recording_Source := Source;
      Recording_Size := 0;
   end Start_Recording;

   --------------------
   -- Stop_Recording --
   --------------------

   procedure Stop_Recording is
   begin
      Recording_Source := None;
   end Stop_Recording;

   -----------------
   -- Record_Size --
   -----------------

   function Record_Size return Natural
   is (Recording_Size);

end WNM.Synth;
