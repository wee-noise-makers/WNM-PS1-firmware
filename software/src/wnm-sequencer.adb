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

with WNM.Short_Term_Sequencer;
with WNM.Pattern_Sequencer;
with WNM.UI; use WNM.UI;
with WNM.MIDI.Queues;
with HAL;                   use HAL;

package body WNM.Sequencer is

   type CC_Val_Array is array (CC_Id) of MIDI.MIDI_Data;
   type CC_Ena_Array is array (CC_Id) of Boolean;

   type Step_Rec is record
      Trig        : Trigger;
      Repeat      : WNM.Repeat;
      Repeat_Rate : WNM.Repeat_Rate;

      Note     : MIDI.MIDI_Key := MIDI.C4;
      Duration : Note_Duration := Quarter;
      Velo     : MIDI.MIDI_Data := MIDI.MIDI_Data'Last;
      CC_Ena   : CC_Ena_Array := (others => False);
      CC_Val   : CC_Val_Array := (others => 0);
   end record;

   type Sequence is array (Sequencer_Steps) of Step_Rec with Pack;
   type Pattern is array (Tracks) of Sequence;
   Sequences : array (Patterns) of Pattern;

   type CC_Setting is record
      Controller : MIDI.MIDI_Data := 0;
      Label      : Controller_Label := "Noname Controller";
   end record;
   type CC_Setting_Array is array (CC_Id) of CC_Setting;

   type Track_Setting is record
      Chan : MIDI.MIDI_Channel := 0;
      CC : CC_Setting_Array;
   end record;

   Track_Settings : array (Tracks) of Track_Setting
     := (others => (Chan => 0,
                    CC => ((0, "Control 0        "),
                           (1, "Control 1        "),
                           (2, "Control 2        "),
                           (3, "Control 3        ")
                           )
                   )
        );

   Sequencer_BPM : Beat_Per_Minute := 120;

   Current_Playing_Step : Sequencer_Steps := Sequencer_Steps'First with Atomic;

   --  Current_Seq_State : Sequencer_State := Pause with Atomic;
   Current_Track     : Tracks := Tracks'First with Atomic;

   Current_Editing_Pattern : Patterns := Patterns'First;
   Current_Editing_Track : Tracks := Tracks'First;
   Current_Editing_Step : Sequencer_Steps := Sequencer_Steps'First;

   Track_Instrument  : array (Tracks) of Keyboard_Value :=
     (others => Keyboard_Value'First);

   --  Next_Start : Synth.Sample_Time := Synth.Sample_Time'First;
   Next_Start : Time.Time_Microseconds := Time.Time_Microseconds'First;

   Pattern_Counter : array (Patterns) of UInt32;
   --  Count how many times a pattern has played

   type Microstep_Cnt is mod 2;
   Microstep : Microstep_Cnt := 1;

   procedure Process_Step (Pattern : Patterns; Step : Sequencer_Steps);

   Rand_X : UInt32 := 123456789;
   Rand_Y : UInt32 := 362436069;
   Rand_Z : UInt32 := 521288629;

   type Rand_Percent is range 0 .. 100;
   function Random return Rand_Percent;

   type Sequencer_State_Event is (Play_Event,
                                  Rec_Event,
                                  Rec_Long_Event,
                                  Rec_Release_Event);
   procedure Do_Preview_Trigger (T : Tracks);
   procedure Play_Step (P : Patterns; T : Tracks; S : Sequencer_Steps;
                        Now : Time.Time_Microseconds := Time.Clock);

   --  ----------------
   --  -- Transition --
   --  ----------------
   --
   --  function Transition (State : Sequencer_State;
   --                       Evt   : Sequencer_State_Event)
   --                       return Sequencer_State
   --  is
   --    (case State is
   --        when Pause =>        (case Evt is
   --                                 when Play_Event        => Play,
   --                                 when Rec_Event         => Edit,
   --                                 when Rec_Long_Event    => Pause,
   --                                 when Rec_Release_Event => Pause),
   --        when Play =>         (case Evt is
   --                                 when Play_Event        => Pause,
   --                                 when Rec_Event         => Play_And_Edit,
   --                                 when Rec_Long_Event    => Play_And_Rec,
   --                                 when Rec_Release_Event => Play),
   --        when Edit =>         (case Evt is
   --                                 when Play_Event        => Play_And_Edit,
   --                                 when Rec_Event         => Pause,
   --                                 when Rec_Long_Event    => Edit,
   --                                 when Rec_Release_Event => Edit),
   --        when Play_And_Edit =>         (case Evt is
   --                                 when Play_Event        => Edit,
   --                                 when Rec_Event         => Play,
   --                                 when Rec_Long_Event    => Play_And_Rec,
   --                                 when Rec_Release_Event => Play_And_Edit),
   --        when Play_And_Rec => (case Evt is
   --                                 when Play_Event        => Pause,
   --                                 when Rec_Event         => Play_And_Rec,
   --                                 when Rec_Long_Event    => Play_And_Rec,
   --                                 when Rec_Release_Event => Play));

   ------------------
   -- Playing_Step --
   ------------------

   function Playing_Step return Sequencer_Steps
   is (Current_Playing_Step);

   ---------------------
   -- Playing_Pattern --
   ---------------------

   function Playing_Pattern return Patterns
   is (Pattern_Sequencer.Playing_Pattern);

   -------------------
   -- Editing_Step --
   -------------------

   function Editing_Step return Sequencer_Steps
   is (Current_Editing_Step);

   --------------------
   -- Editing_Track --
   --------------------

   function Editing_Track return Tracks
   is (Current_Editing_Track);

   ----------------------
   -- Editing_Pattern --
   ----------------------

   function Editing_Pattern return Patterns
   is (Current_Editing_Pattern);

   procedure Set_Editing_Step    (S : Sequencer_Steps) is
   begin
      Current_Editing_Step := S;
   end Set_Editing_Step;

   -----------------------
   -- Set_Editing_Track --
   -----------------------

   procedure Set_Editing_Track   (T : Tracks) is
   begin
      Current_Editing_Track := T;
   end Set_Editing_Track;

   -------------------------
   -- Set_Editing_Pattern --
   -------------------------

   procedure Set_Editing_Pattern (P : Patterns) is
   begin
      Current_Editing_Pattern := P;
   end Set_Editing_Pattern;

   ------------------------
   -- Do_Preview_Trigger --
   ------------------------

   procedure Do_Preview_Trigger (T : Tracks) is
      use WNM.Synth;
   begin
      WNM.MIDI.Queues.Sequencer_Push
        ((MIDI.Note_On,
         WNM.MIDI.To_MIDI_Channel (T),
         MIDI.C4,
         40));
      WNM.Short_Term_Sequencer.Push
        ((MIDI.Note_Off,
         WNM.MIDI.To_MIDI_Channel (T),
         MIDI.C4,
         0),
         Time.Clock + Microseconds_Per_Beat);
   end Do_Preview_Trigger;

--      Octave : MIDI.Octaves := 4;

--     function To_Key (B : Keyboard_Buttons; Oct : MIDI.Octaves)
--  return MIDI.MIDI_Key is
--       (case B is
--           when B9  => MIDI.Key (Oct, MIDI.C),
--           when B2  => MIDI.Key (Oct, MIDI.Cs),
--           when B10 => MIDI.Key (Oct, MIDI.D),
--           when B3  => MIDI.Key (Oct, MIDI.Ds),
--           when B11 => MIDI.Key (Oct, MIDI.E),
--           when B12 => MIDI.Key (Oct, MIDI.F),
--           when B5  => MIDI.Key (Oct, MIDI.Fs),
--           when B13 => MIDI.Key (Oct, MIDI.G),
--           when B6  => MIDI.Key (Oct, MIDI.Gs),
--           when B14 => MIDI.Key (Oct, MIDI.A),
--           when B7  => MIDI.Key (Oct, MIDI.As),
--           when B15 => MIDI.Key (Oct, MIDI.B),
--           when B16 => MIDI.Key (Oct + 1, MIDI.C),
--           when others => MIDI.A0);

   ----------------
   -- Play_Pause --
   ----------------

   procedure Play_Pause is
   begin
      if not Pattern_Sequencer.Playing then
         Current_Playing_Step := Sequencer_Steps'First;
         Microstep := 1;
         Execute_Step;
      end if;

      Pattern_Sequencer.Play_Pause;

   end Play_Pause;

   --------------
   -- On_Press --
   --------------

   procedure On_Press (Button : Keyboard_Button;
                       Mode   : WNM.UI.Main_Modes)
   is
      V : constant Keyboard_Value := To_Value (Button);
   begin
      case Mode is
         when UI.Pattern_Mode =>
            Current_Editing_Pattern := V;
            Pattern_Sequencer.On_Press (Button, Mode);

         when UI.Track_Mode | UI.Step_Mode =>

            if Mode = UI.Track_Mode and then not UI.Recording then
               Current_Editing_Track := V;
            else
               Current_Editing_Step := V;
            end if;

            --  if UI.Recording and then Pattern_Sequencer.Playing then
            --
            --     --  Live record the trigger
            --     Sequences (Current_Editing_Pattern) (V) (Current_Playing_Step).Trig
            --       := Always;
            --
            --     if Microstep /= 1 then
            --        --  If user play later than the step time, play a preview
            --        Do_Preview_Trigger (V);
            --     end if;
            --  else
            --     Do_Preview_Trigger (V);
            --  end if;

            if UI.Recording then
               declare
                  S : Step_Rec renames Sequences
                    (Editing_Pattern)
                    (Editing_Track)
                    (To_Value (Button));
               begin
                  if S.Trig /= None then
                     S.Trig := None;
                  else
                     S.Trig := Always;
                  end if;
               end;
            else
               if Mode = UI.Step_Mode then
                  Play_Step (Editing_Pattern,
                             Editing_Track,
                             To_Value (Button));
               else
                  Do_Preview_Trigger (V);

               end if;
            end if;
      end case;
   end On_Press;

   ----------------
   -- On_Release --
   ----------------

   procedure On_Release (Button : Keyboard_Button;
                         Mode   : WNM.UI.Main_Modes)
   is
   begin
      Pattern_Sequencer.On_Release (Button, Mode);
   end On_Release;

   --------------------
   -- Select_Channel --
   --------------------

   procedure Select_Track (Track : Tracks) is
   begin
      Current_Track := Track;
   end Select_Track;

   -------------
   -- Do_Copy --
   -------------

   procedure Do_Copy (T : in out WNM.Sequence_Copy.Copy_Transaction) is
      use WNM.Sequence_Copy;
   begin
      case T.From.Kind is
         when WNM.Sequence_Copy.Pattern =>
            Sequences (T.To.P) := Sequences (T.From.P);

            --  Step back in destination address to allow for a new copy
            --  imediately.
            T.To.State := Sequence_Copy.None;
         when Track =>
            Sequences (T.To.P) (T.To.T) :=
              Sequences (T.From.P) (T.From.T);

            --  Step back in destination address to allow for a new copy
            --  imediately.
            T.To.State := Sequence_Copy.Pattern;
         when Step =>
            Sequences (T.To.P) (T.To.T) (T.To.S) :=
              Sequences (T.From.P) (T.From.T) (T.From.S);

            --  Step back in destination address to allow for a new copy
            --  imediately.
            T.To.State := Sequence_Copy.Track;
      end case;

   end Do_Copy;

   --------------------
   -- Set_Instrument --
   --------------------

   procedure Set_Instrument (Val : Keyboard_Value) is
   begin
      Track_Instrument (Current_Track) := Val;
   end Set_Instrument;

   ----------------
   -- Instrument --
   ----------------

   function Instrument (Track : Tracks) return Keyboard_Value
   is (Track_Instrument (Track));

   -------------
   -- Set_BPM --
   -------------

   procedure Set_BPM (BPM : Beat_Per_Minute) is
   begin
      Sequencer_BPM := BPM;
   end Set_BPM;

   ----------------
   -- Change_BPM --
   ----------------

   procedure Change_BPM (BPM_Delta : Integer) is
      Res : Integer;
   begin
      Res := Integer (Sequencer_BPM) + BPM_Delta;
      if Res in Beat_Per_Minute then
         Sequencer_BPM := Res;
      end if;
   end Change_BPM;

   ---------
   -- BPM --
   ---------

   function BPM return Beat_Per_Minute
   is (Sequencer_BPM);

   ----------------------
   -- Samples_Per_Beat --
   ----------------------

   function Samples_Per_Beat return Synth.Sample_Time is
      use Synth;

      Samples_Per_Minute : constant Sample_Time := 60 * Sample_Frequency;
   begin
      return Samples_Per_Minute / Sample_Time (Sequencer_BPM);
   end Samples_Per_Beat;

   ---------------------------
   -- Microseconds_Per_Beat --
   ---------------------------

   function Microseconds_Per_Beat return Time.Time_Microseconds is
   begin
      return (60 * 1_000 * 1_000) / Time.Time_Microseconds (Sequencer_BPM);
   end Microseconds_Per_Beat;

   ------------
   -- Random --
   ------------

   function Random return Rand_Percent is
      T : UInt32;
   begin
      Rand_X := Rand_X xor Shift_Left (Rand_X, 16);
      Rand_X := Rand_X xor Shift_Right (Rand_X, 5);
      Rand_X := Rand_X xor Shift_Left (Rand_X, 1);

      T := Rand_X;
      Rand_X := Rand_Y;
      Rand_Y := Rand_Z;
      Rand_Z := T xor Rand_X xor Rand_Y;

      return Rand_Percent (Rand_Z mod 100);
   end Random;

   ---------------
   -- Play_Step --
   ---------------

   procedure Play_Step (P : Patterns; T : Tracks; S : Sequencer_Steps;
                        Now : Time.Time_Microseconds := Time.Clock)
   is
      Step : Step_Rec renames Sequences (P) (T) (S);

      Note_Duration : constant Time.Time_Microseconds :=
        (case Step.Duration
         is
            when Double  => Microseconds_Per_Beat * 2,
            when Whole   => Microseconds_Per_Beat,
            when Half    => Microseconds_Per_Beat / 2,
            when Quarter => Microseconds_Per_Beat / 4,
            when N_8th   => Microseconds_Per_Beat / 8,
            when N_16th  => Microseconds_Per_Beat / 16,
            when N_32nd  => Microseconds_Per_Beat / 32);

      Channel : constant MIDI.MIDI_Channel :=  Track_Settings (T).Chan;
   begin
      WNM.MIDI.Queues.Sequencer_Push
        ((MIDI.Note_On,
         Channel,
         Step.Note,
         Step.Velo));
      declare
         Repeat_Span : constant Time.Time_Microseconds :=
           Microseconds_Per_Beat / (case Step.Repeat_Rate
                                    is
                                       when Rate_1_2  => 2,
                                       when Rate_1_3  => 3,
                                       when Rate_1_4  => 4,
                                       when Rate_1_5  => 5,
                                       when Rate_1_6  => 6,
                                       when Rate_1_8  => 8,
                                       when Rate_1_10 => 10,
                                       when Rate_1_12 => 12,
                                       when Rate_1_16 => 16,
                                       when Rate_1_20 => 20,
                                       when Rate_1_24 => 24,
                                       when Rate_1_32 => 32);

         Repeat_Duration : constant Time.Time_Microseconds :=
           (if Step.Repeat /= 0 and then Repeat_Span < Note_Duration
            then Repeat_Span
            else Note_Duration);

         Repeat_Time : Time.Time_Microseconds := Now + Repeat_Span;
      begin
         --  Note-Off for the first Note-On, its duration depends if
         --  there is a repeat and the repeat rate.
         WNM.Short_Term_Sequencer.Push
           ((MIDI.Note_Off,
            Channel,
            Step.Note,
            0),
            Now + Repeat_Duration);

         for Rep in 1 .. Step.Repeat loop
            WNM.Short_Term_Sequencer.Push
              ((MIDI.Note_On,
               Channel,
               Step.Note,
               Step.Velo),
               Repeat_Time);
            WNM.Short_Term_Sequencer.Push
              ((MIDI.Note_Off,
               Channel,
               Step.Note,
               0),
               Repeat_Time + Repeat_Duration);

            Repeat_Time := Repeat_Time + Repeat_Span;
         end loop;
      end;
   end Play_Step;

   ------------------
   -- Process_Step --
   ------------------

   procedure Process_Step (Pattern : Patterns;
                           Step : Sequencer_Steps)
   is
      use Synth;

      Condition : Boolean := False;

      Now : constant Time.Time_Microseconds := Time.Clock;
      Note_Duration : constant Time.Time_Microseconds :=
        Microseconds_Per_Beat / 4;

      --  Now : constant Sample_Time := Sample_Clock;
      --  Note_Duration : constant Sample_Time := Samples_Per_Beat / 4;
   begin
      if Step = Sequencer_Steps'First then
         Pattern_Counter (Pattern) := Pattern_Counter (Pattern) + 1;
      end if;

      for Track in Tracks loop
         declare
            S : Step_Rec renames Sequences (Pattern) (Track) (Step);
         begin
            case S.Trig is
            when None =>
               Condition := False;
            when Always =>
               Condition := True;
            when Fill =>
               Condition := WNM.UI.FX_On (B1);
            when Percent_25 =>
               Condition := Random <= 25;
            when Percent_50 =>
               Condition := Random <= 50;
            when Percent_75 =>
               Condition := Random <= 75;
            when One_Of_Two =>
               Condition := Pattern_Counter (Pattern) mod 2 = 0;
            when One_Of_Three =>
               Condition := Pattern_Counter (Pattern) mod 3 = 0;
            end case;

            --  Send CC first
            declare
               Channel : constant MIDI.MIDI_Channel :=
                 Track_Settings (Track).Chan;
            begin
               for Id in CC_Id loop
                  if S.CC_Ena (Id) then
                     WNM.MIDI.Queues.Sequencer_Push
                       ((MIDI.Continous_Controller,
                        Channel,
                        Track_Settings (Track).CC (Id).Controller,
                        S.CC_Val (Id)));
                  end if;
               end loop;
            end;

            --  Play note
            if Condition then
               Play_Step (Pattern, Track, Step, Now);
            end if;

         end;
      end loop;
   end Process_Step;

   ------------------
   -- Execute_Step --
   ------------------

   procedure Execute_Step is
      use Synth;
   begin

      Next_Start := Next_Start + (Microseconds_Per_Beat / Steps_Per_Beat) / 2;

      if Pattern_Sequencer.Playing then
         case Microstep is

            --  Begining of a new step
            when 0 =>
               if Current_Playing_Step /= Sequencer_Steps'Last then
                  Current_Playing_Step := Current_Playing_Step + 1;
               else
                  Current_Playing_Step := Sequencer_Steps'First;
                  Pattern_Sequencer.Signal_End_Of_Pattern;
               end if;

               --  At the middle of the step we play the recorded notes
            when 1 =>
               Process_Step (Pattern_Sequencer.Playing_Pattern,
                             Playing_Step);
         end case;

         Microstep := Microstep + 1;
      end if;
   end Execute_Step;

   ------------
   -- Update --
   ------------

   function Update return Time.Time_Microseconds is
      use Synth;

      Now : constant Time.Time_Microseconds := Time.Clock;
      Success : Boolean;
      Msg     : WNM.MIDI.Message;
   begin
      if Now >= Next_Start then
         Execute_Step;
      end if;

      loop
         WNM.Short_Term_Sequencer.Pop (Now, Msg, Success);
         exit when not Success;

         WNM.MIDI.Queues.Sequencer_Push (Msg);
      end loop;

      return Time.Time_Microseconds'First;
   end Update;

   ---------
   -- Set --
   ---------

   function Set (Step : Sequencer_Steps) return Boolean is
   begin
      return Sequences (Editing_Pattern) (Editing_Track) (Step).Trig /= None;
   end Set;

   ---------
   -- Set --
   ---------

   function Set (Track : Tracks; Step : Sequencer_Steps) return Boolean is
   begin
      return Sequences (Editing_Pattern) (Track) (Step).Trig /= None;
   end Set;

   ----------
   -- Trig --
   ----------

   function Trig (Step : Sequencer_Steps) return Trigger is
   begin
      return Sequences (Editing_Pattern) (Editing_Track) (Step).Trig;
   end Trig;

   ---------------
   -- Trig_Next --
   ---------------

   procedure Trig_Next (Step : Sequencer_Steps) is
   begin
      Next (Sequences (Editing_Pattern)(Editing_Track) (Step).Trig);
   end Trig_Next;

   ---------------
   -- Trig_Prev --
   ---------------

   procedure Trig_Prev (Step : Sequencer_Steps) is
   begin
      Prev (Sequences (Editing_Pattern)(Editing_Track) (Step).Trig);
   end Trig_Prev;

   ------------
   -- Repeat --
   ------------

   function Repeat (Step : Sequencer_Steps) return WNM.Repeat is
   begin
      return Sequences
        (Editing_Pattern) (Editing_Track) (Step).Repeat;
   end Repeat;

   -----------------
   -- Repeat_Next --
   -----------------

   procedure Repeat_Next (Step : Sequencer_Steps) is
   begin
      Next (Sequences
            (Editing_Pattern) (Editing_Track) (Step).Repeat);
   end Repeat_Next;

   -----------------
   -- Repeat_Prev --
   -----------------

   procedure Repeat_Prev (Step : Sequencer_Steps) is
   begin
      Prev (Sequences
            (Editing_Pattern) (Editing_Track) (Step).Repeat);
   end Repeat_Prev;

   -----------------
   -- Repeat_Rate --
   -----------------

   function Repeat_Rate (Step : Sequencer_Steps) return WNM.Repeat_Rate is
   begin
      return Sequences
        (Editing_Pattern) (Editing_Track) (Step).Repeat_Rate;
   end Repeat_Rate;

   ----------------------
   -- Repeat_Rate_Next --
   ----------------------

   procedure Repeat_Rate_Next (Step : Sequencer_Steps) is
   begin
      Next (Sequences
            (Editing_Pattern)
            (Editing_Track)
            (Step).Repeat_Rate);
   end Repeat_Rate_Next;

   ----------------------
   -- Repeat_Rate_Prev --
   ----------------------

   procedure Repeat_Rate_Prev (Step : Sequencer_Steps) is
   begin
      Prev (Sequences
            (Editing_Pattern)
            (Editing_Track)
            (Step).Repeat_Rate);
   end Repeat_Rate_Prev;

   ----------
   -- Note --
   ----------

   function Note (Step : Sequencer_Steps) return MIDI.MIDI_Key is
   begin
      return Sequences
        (Editing_Pattern) (Editing_Track) (Step).Note;
   end Note;

   ---------------
   -- Note_Next --
   ---------------

   procedure Note_Next (Step : Sequencer_Steps) is
      CC : MIDI.MIDI_Key renames Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).Note;
   begin
      if CC /= MIDI.MIDI_Key'Last then
         CC := CC + 1;
      end if;
   end Note_Next;

   ---------------
   -- Note_Prev --
   ---------------

   procedure Note_Prev (Step : Sequencer_Steps) is
      CC : MIDI.MIDI_Key renames Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).Note;
   begin
      if CC /= MIDI.MIDI_Key'First then
         CC := CC - 1;
      end if;
   end Note_Prev;

   -------------------
   -- Note_Duration --
   -------------------

   function Duration (Step : Sequencer_Steps) return Note_Duration is
   begin
      return Sequences (Editing_Pattern) (Editing_Track) (Step).Duration;
   end Duration;

   -------------------
   -- Duration_Next --
   -------------------

   procedure Duration_Next (Step : Sequencer_Steps) is
   begin
      Next (Sequences
            (Editing_Pattern)
            (Editing_Track)
            (Step).Duration);
   end Duration_Next;

   -------------------
   -- Duration_Prev --
   -------------------

   procedure Duration_Prev (Step : Sequencer_Steps) is
   begin
      Prev (Sequences
            (Editing_Pattern)
            (Editing_Track)
            (Step).Duration);
   end Duration_Prev;

   ----------
   -- Velo --
   ----------

   function Velo (Step : Sequencer_Steps) return MIDI.MIDI_Data is
      V : MIDI.MIDI_Data renames Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).Velo;
   begin
      return V;
   end Velo;

   ---------------
   -- Velo_Next --
   ---------------

   procedure Velo_Next (Step : Sequencer_Steps) is
      V : MIDI.MIDI_Data renames Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).Velo;
   begin
      if V /= MIDI.MIDI_Data'Last then
         V := V + 1;
      end if;
   end Velo_Next;

   ---------------
   -- Velo_Prev --
   ---------------

   procedure Velo_Prev (Step : Sequencer_Steps) is
      V : MIDI.MIDI_Data renames Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).Velo;
   begin
      if V /= MIDI.MIDI_Data'First then
         V := V - 1;
      end if;
   end Velo_Prev;

   ---------------
   -- MIDI_Chan --
   ---------------

   function MIDI_Chan (T : Tracks) return MIDI.MIDI_Channel is
   begin
      return Track_Settings (T).Chan;
   end MIDI_Chan;

   --------------------
   -- MIDI_Chan_Next --
   --------------------

   procedure MIDI_Chan_Next (T : Tracks) is
      use MIDI;
   begin
      if Track_Settings (T).Chan /= MIDI.MIDI_Channel'Last then
         Track_Settings (T).Chan :=  Track_Settings (T).Chan + 1;
      end if;
   end MIDI_Chan_Next;

   --------------------
   -- MIDI_Chan_Prev --
   --------------------

   procedure MIDI_Chan_Prev (T : Tracks) is
      use MIDI;
   begin
      if Track_Settings (T).Chan /= MIDI.MIDI_Channel'First then
         Track_Settings (T).Chan :=  Track_Settings (T).Chan - 1;
      end if;
   end MIDI_Chan_Prev;

   -------------------
   -- CC_Controller --
   -------------------

   function CC_Controller (T : Tracks; Id : CC_Id) return MIDI.MIDI_Data
   is (Track_Settings (T).CC (Id).Controller);

   -----------------------
   -- Set_CC_Controller --
   -----------------------

   procedure Set_CC_Controller (T : Tracks; Id : CC_Id; C : MIDI.MIDI_Data) is
   begin
      Track_Settings (T).CC (Id).Controller := C;
   end Set_CC_Controller;

   ------------------------
   -- CC_Controller_Next --
   ------------------------

   procedure CC_Controller_Next (T : Tracks; Id : CC_Id) is
      use MIDI;

      Controller : MIDI_Data renames Track_Settings (T).CC (Id).Controller;
   begin
      if Controller /= MIDI_Data'Last then
         Controller := Controller + 1;
      end if;
   end CC_Controller_Next;

   ------------------------
   -- CC_Controller_Prev --
   ------------------------

   procedure CC_Controller_Prev (T : Tracks; Id : CC_Id) is
      use MIDI;

      Controller : MIDI_Data renames Track_Settings (T).CC (Id).Controller;
   begin
      if Controller /= MIDI_Data'First then
         Controller := Controller - 1;
      end if;
   end CC_Controller_Prev;

   ----------------------------
   -- Set_CC_Controller_Name --
   ----------------------------

   procedure Set_CC_Controller_Label (T     : Tracks;
                                      Id    : CC_Id;
                                      Label : Controller_Label)
   is
   begin
      Track_Settings (T).CC (Id).Label := Label;
   end Set_CC_Controller_Label;

   -------------------------
   -- CC_Controller_Label --
   -------------------------

   function CC_Controller_Label (T    : Tracks;
                                 Id   : CC_Id)
                                 return Controller_Label
   is (Track_Settings (T).CC (Id).Label);

   ----------------
   -- CC_Enabled --
   ----------------

   function CC_Enabled (Step : Sequencer_Steps; Id : CC_Id) return Boolean is
   begin
      return Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).CC_Ena (Id);
   end CC_Enabled;

   ---------------
   -- CC_Toggle --
   ---------------

   procedure CC_Toggle (Step : Sequencer_Steps; Id : CC_Id) is
      CC : Boolean renames Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).CC_Ena (Id);
   begin
      CC := not CC;
   end CC_Toggle;

   --------------
   -- CC_Value --
   --------------

   function CC_Value (Step : Sequencer_Steps; Id : CC_Id) return MIDI.MIDI_Data
   is
   begin
      return Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).CC_Val (Id);
   end CC_Value;

   ------------------
   -- CC_Value_Inc --
   ------------------

   procedure CC_Value_Inc (Step : Sequencer_Steps; Id : CC_Id) is
      CC : MIDI.MIDI_Data renames Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).CC_Val (Id);
   begin
      if CC /= MIDI.MIDI_Data'Last then
         CC := CC + 1;
      end if;

      --  Enable when the value is changed
      Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).CC_Ena (Id) := True;
   end CC_Value_Inc;

   ------------------
   -- CC_Value_Dec --
   ------------------

   procedure CC_Value_Dec (Step : Sequencer_Steps; Id : CC_Id) is
      CC : MIDI.MIDI_Data renames Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).CC_Val (Id);
   begin
      if CC /= MIDI.MIDI_Data'First then
         CC := CC - 1;
      end if;

      --  Enable when the value is changed
      Sequences
        (Editing_Pattern)
        (Editing_Track)
        (Step).CC_Ena (Id) := True;
   end CC_Value_Dec;

begin
   for Pattern in Patterns loop
      for Track in Tracks loop
         Track_Settings (Track).Chan := MIDI.MIDI_Channel (Integer (Track) - 1);
         for Step in Sequencer_Steps loop
            Sequences (Pattern) (Track) (Step) := (None, 0, Rate_1_2,
                                                   others => <>);
         end loop;
      end loop;
   end loop;

   --  Sequences (B1) (B1) (1)  := (Always, 3, Rate_1_8, others => <>);
   --  Sequences (B1) (B2) (2)  := (Always, 0, Rate_1_8);
   --  Sequences (B1) (B3) (3)  := (Always, 0, Rate_1_8);
   --  Sequences (B1) (B4) (4)  := (Always, 0, Rate_1_8);
   --  Sequences (B1) (B5) (5)  := (Always, 3, Rate_1_8, others => <>);
   --  Sequences (B1) (B6) (6)  := (Always, 0, Rate_1_8);
   --  Sequences (B1) (B7) (7)  := (Always, 0, Rate_1_8);
   --  Sequences (B1) (B8) (8)  := (Always, 0, Rate_1_8);
   --  Sequences (B1) (B9) (9)  := (Always, 3, Rate_1_8, others => <>);
   --  Sequences (B1) (B10) (10) := (Always, 0, Rate_1_8);
   --  Sequences (B1) (B11) (11) := (Always, 0, Rate_1_8);
   --  Sequences (B1) (B12) (12) := (Always, 0, Rate_1_8);
   --  Sequences (B1) (B13) (13) := (Always, 3, Rate_1_8, others => <>);
   --  Sequences (B1) (B14) (14) := (Always, 0, Rate_1_8);
   --  Sequences (B1) (B15) (15) := (Always, 0, Rate_1_8);
   --  Sequences (B1) (B16) (16) := (Always, 0, Rate_1_8);
end WNM.Sequencer;
