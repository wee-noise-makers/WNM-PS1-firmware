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

with MIDI;

with WNM.GUI.Menu.Drawing; use WNM.GUI.Menu.Drawing;
with WNM.GUI.Bitmap_Fonts;
with WNM.Chord_Settings;
with WNM.Utils;

package body WNM.GUI.Menu.Chord_Settings is

   package Sub_Settings_Next is new Enum_Next (Sub_Settings,
                                               Wrap => False);
   use Sub_Settings_Next;

   Pattern_Menu_Singleton : aliased Pattern_Settings_Menu;

   -----------------
   -- Push_Window --
   -----------------

   procedure Push_Window is
   begin
      Push (Pattern_Menu_Singleton'Access);
   end Push_Window;

   ------------
   -- To_Top --
   ------------

   function To_Top (S : Sub_Settings) return Top_Settings
   is (case S is
          when WNM.Project.Tonic    => Chord_Type,
          when WNM.Project.Name     => Chord_Type,
          when WNM.Project.Duration => Chord_Type);

   ----------
   -- Draw --
   ----------

   overriding
   procedure Draw (This : in out Pattern_Settings_Menu)
   is
      use WNM.Chord_Settings;
      use WNM.Project;

      Sub : constant Sub_Settings := This.Current_Setting;
      Top : constant Top_Settings := To_Top (Sub);

      Tonic : constant MIDI.MIDI_Key := WNM.Project.Selected_Tonic;
      Name : constant WNM.Chord_Settings.Chord_Name :=
        WNM.Project.Selected_Name;
      Duration : constant WNM.Project.Chord_Step_Duration :=
        WNM.Project.Selected_Duration;

      Notes : constant WNM.Chord_Settings.Chord_Notes :=
        Tonic + WNM.Chord_Settings.Chords (Name);
   begin
      Draw_Menu_Box ("Chord settings",
                     Count => Top_Settings_Count,
                     Index => Top_Settings'Pos (Top));

      case Top is
         when Chord_Type =>
            Draw_MIDI_Note (Tonic,
                            Sub = WNM.Project.Tonic);

            Draw_Value_Pos (WNM.Chord_Settings.Img (Name),
                            WNM.GUI.Menu.Drawing.Box_Center.X - 32,
                            Sub = WNM.Project.Name);

            Draw_Value_Pos (Utils.Trim (Duration'Img) & "Stps",
                            WNM.GUI.Menu.Drawing.Box_Center.X + 21,
                            Sub = WNM.Project.Duration);

            declare
               X : Natural := Menu.Drawing.Box_Left + 5;
            begin
               for K of Notes loop
                  GUI.Bitmap_Fonts.Print (X,
                                          Menu.Drawing.Box_Top + 10,
                                          Key_Img (K));
                  GUI.Bitmap_Fonts.Print (X,
                                          Menu.Drawing.Box_Top + 10,
                                          " ");
               end loop;
            end;
      end case;

   end Draw;

   --------------
   -- On_Event --
   --------------

   overriding
   procedure On_Event (This  : in out Pattern_Settings_Menu;
                       Event : Menu_Event)
   is
   begin
      case Event.Kind is
         when Left_Press =>
            Prev (This.Current_Setting);
         when Right_Press =>
            Next (This.Current_Setting);
         when Up_Press =>
            WNM.Project.Next_Value (This.Current_Setting);
         when Down_Press =>
            WNM.Project.Prev_Value (This.Current_Setting);
         when A_Press =>
            null;
         when B_Press =>
            null;
         when Slider_Touch =>
            null; --  TODO
      end case;
   end On_Event;

   ---------------
   -- On_Pushed --
   ---------------

   overriding
   procedure On_Pushed (This  : in out Pattern_Settings_Menu)
   is
   begin
      null;
   end On_Pushed;

   --------------
   -- On_Focus --
   --------------

   overriding
   procedure On_Focus (This       : in out Pattern_Settings_Menu;
                       Exit_Value : Window_Exit_Value)
   is
   begin
      null;
   end On_Focus;

end WNM.GUI.Menu.Chord_Settings;
