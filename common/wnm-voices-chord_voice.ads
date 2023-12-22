-------------------------------------------------------------------------------
--                                                                           --
--                              Wee Noise Maker                              --
--                                                                           --
--                     Copyright (C) 2023 Fabien Chouteau                    --
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

with Tresses;            use Tresses;
with Tresses.Interfaces; use Tresses.Interfaces;

private with Tresses.Envelopes.AR;
private with Tresses.Analog_Oscillator;

package WNM.Voices.Chord_Voice is

   type Instance
   is new Four_Params_Voice
   with private;

   procedure Init (This : in out Instance);

   procedure Render (This   : in out Instance;
                     Buffer :    out Tresses.Mono_Buffer);

   procedure Key_On (This     : in out Instance;
                     Key      :        MIDI.MIDI_Key;
                     Velocity :        Tresses.Param_Range);

   procedure Key_Off (This : in out Instance;
                      Key  :        MIDI.MIDI_Key);

   P_Shape   : constant Tresses.Param_Id := 1;
   P_Color   : constant Tresses.Param_Id := 2;
   P_Attack  : constant Tresses.Param_Id := 3;
   P_Release : constant Tresses.Param_Id := 4;

   --  Interfaces --

   overriding
   function Param_Label (This : Instance; Id : Param_Id) return String
   is (case Id is
          when P_Color   => "Color",
          when P_Shape   => "Shape",
          when P_Attack  => "Attack",
          when P_Release => "Release");

   overriding
   function Param_Short_Label (This : Instance; Id : Param_Id)
                               return Short_Label
   is (case Id is
          when P_Color   => "COL",
          when P_Shape   => "SHP",
          when P_Attack  => "ATK",
          when P_Release => "REL");

private
   type Voice is record
      On : Boolean;
      Note : MIDI.MIDI_Key;

      Env : Tresses.Envelopes.AR.Instance;
      Osc : Tresses.Analog_Oscillator.Instance;
   end record;

   Chord_Voices : constant := 4;
   type Voice_Id is range 1 .. Chord_Voices;
   type Voice_Array is array (Voice_Id) of Voice;

   type Instance
   is new Four_Params_Voice
   with record
      Next : Voice_Id := Voice_Id'First;
      Voices : Voice_Array;

      Do_Init : Boolean := True;
   end record;

end WNM.Voices.Chord_Voice;
