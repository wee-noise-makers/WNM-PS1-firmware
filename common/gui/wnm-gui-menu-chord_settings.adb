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
with WNM.Screen;
with WNM.Utils;

package body WNM.GUI.Menu.Chord_Settings is

   package Chord_Sub_Settings_Next is new Enum_Next (Chord_Sub_Settings,
                                                     Wrap => False);
   use Chord_Sub_Settings_Next;

   package Part_Sub_Settings_Next is new Enum_Next (Part_Sub_Settings,
                                                    Wrap => False);
   use Part_Sub_Settings_Next;

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

   function To_Top (S : Chord_Sub_Settings) return Chord_Top_Settings
   is (case S is
          when WNM.Project.Tonic    => Chord_Type,
          when WNM.Project.Name     => Chord_Type,
          when WNM.Project.Duration => Chord_Type);

   ------------
   -- To_Top --
   ------------

   function To_Top (S : Part_Sub_Settings) return Part_Top_Settings
   is (case S is
          when WNM.Project.Part_Patterns    => Part_Main,
          when WNM.Project.Part_Progression => Part_Main,
          when WNM.Project.Part_Link        => Part_Main);

   Track_Cell_Size  : constant := 12;
   Track_Box_Width  : constant := 8 * Track_Cell_Size;
   Track_Box_Height : constant := 2 * Track_Cell_Size;
   Track_Box_Left   : constant := (Screen.Width - Track_Box_Width) / 2;
   Track_Box_Top    : constant := Drawing.Box_Top + 2;
   Track_Box_Bottom : constant := Track_Box_Top + Track_Box_Height;
   Track_Box_Right  : constant := Track_Box_Left + Track_Box_Width;

   ---------------
   -- Draw_Grid --
   ---------------

   procedure Draw_Grid (This  : Pattern_Settings_Menu;
                        Part  : Parts;
                        Focus : Boolean)
   is
   begin
      for Cnt in 0 .. 8 loop
         declare
            X : constant Natural := Track_Box_Left +
              Cnt * Track_Cell_Size;
         begin
            Screen.Draw_Line ((X, Track_Box_Top),
                              (X, Track_Box_Bottom));
         end;
      end loop;

      for Cnt in 0 .. 2 loop
         declare
            Y : constant Natural := Track_Box_Top +
              Cnt * Track_Cell_Size;
         begin
            Screen.Draw_Line ((Track_Box_Left, Y),
                              (Track_Box_Right, Y));
         end;
      end loop;

      declare
         Top_Margin : constant := 1 +
           (Track_Cell_Size - Bitmap_Fonts.Height) / 2;

         Left_Margin : constant := 1 +
           (Track_Cell_Size - Bitmap_Fonts.Width) / 2;
      begin
         for Y in 0 .. 1 loop
            for X in 0 .. 7 loop
               declare
                  T : constant Tracks := Tracks (X + 1 + Y * 8);
                  C : constant String :=
                    (if Project.Part_Muted (Part, T)
                     then " "
                     else (case Project.Part_Pattern (Part, T) is
                          when 1 => "1",
                          when 2 => "2",
                          when 3 => "3",
                          when 4 => "4",
                          when 5 => "5",
                          when 6 => "6",
                          when 7 => "7",
                          when 8 => "8",
                          when 9 => "9",
                          when 10 => "A",
                          when 11 => "B",
                          when 12 => "C",
                          when 13 => "D",
                          when 14 => "E",
                          when 15 => "F",
                          when 16 => "G"));

                  X_Off : Integer :=
                    Track_Box_Left +
                      X * Track_Cell_Size +
                        Left_Margin;
                  Y_Off : constant Integer :=
                    Track_Box_Top +
                      Y * Track_Cell_Size +
                        Top_Margin;
               begin

                  if Focus and then T = This.Selected then
                     Screen.Fill_Rect (((X_Off - Left_Margin,
                                         Y_Off - Top_Margin),
                                        Track_Cell_Size,
                                        Track_Cell_Size));
                     Bitmap_Fonts.Print
                       (X_Off, Y_Off, C,
                        Invert_From => X_Off,
                        Invert_To   => X_Off + Bitmap_Fonts.Width);
                  else
                     Bitmap_Fonts.Print
                       (X_Off, Y_Off, C);
                  end if;
               end;
            end loop;
         end loop;
      end;
   end Draw_Grid;

   --------------------
   -- Draw_Song_Part --
   --------------------

   procedure Draw_Song_Part (This : in out Pattern_Settings_Menu;
                             Part : Parts)
   is
      use WNM.Project;

      Sub : constant Part_Sub_Settings := This.Current_Part_Setting;
      Top : constant Part_Top_Settings := To_Top (Sub);
   begin

      Draw_Grid (This, Part,
                 Focus => Sub = Project.Part_Patterns);

      Draw_Menu_Box ("Part settings",
                     Count => Part_Top_Settings_Count,
                     Index => Part_Top_Settings'Pos (Top));

      Draw_Value_Pos ("Chords:" & Project.Part_Chords (Part)'Img,
                      Box_Left + 2,
                      Sub = Project.Part_Progression);
      Draw_Value_Pos ("Link:" & Project.Part_Link (Part)'Img,
                      60,
                      Sub = Project.Part_Link);
   end Draw_Song_Part;

   ---------------------
   -- Draw_Song_Chord --
   ---------------------

   procedure Draw_Song_Chord (This  : in out Pattern_Settings_Menu;
                              Prog : Chord_Progressions)
   is
      use WNM.Chord_Settings;
      use WNM.Project;

      Sub : constant Chord_Sub_Settings := This.Current_Chord_Setting;
      Top : constant Chord_Top_Settings := To_Top (Sub);

      Id    : constant Project.Chord_Slot_Id := This.Selected_Chord;
      Len   : constant Project.Chord_Slot_Id :=
        WNM.Project.Progression_Length (Prog);

      Tonic : constant MIDI.MIDI_Key :=
        WNM.Project.Selected_Tonic (Prog, Id);
      Name : constant WNM.Chord_Settings.Chord_Name :=
        WNM.Project.Selected_Name (Prog, Id);
      Duration : constant WNM.Project.Chord_Step_Duration :=
        WNM.Project.Selected_Duration (Prog, Id);

      Notes : constant WNM.Chord_Settings.Chord_Notes :=
        Tonic + WNM.Chord_Settings.Chords (Name);
   begin

      Draw_Menu_Box ("Chord settings",
                     Count => Natural (Len) + 1,
                     Index => Natural (Id) - 1);

      if Id > Len then
         Draw_Title ("A: add a chord",
                     "B: remove a chord");
      else

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
      end if;

   end Draw_Song_Chord;

   ----------
   -- Draw --
   ----------

   overriding
   procedure Draw (This : in out Pattern_Settings_Menu)
   is
      Elt : constant Song_Element := Project.Editing_Song_Elt;
   begin
      case Elt is
         when Parts =>
            Draw_Song_Part (This, Parts (Elt));
         when Chord_Progressions =>
            Draw_Song_Chord (This, Chord_Progressions (Elt));
      end case;
   end Draw;

   -------------------
   -- On_Part_Event --
   -------------------

   procedure On_Part_Event (This  : in out Pattern_Settings_Menu;
                            Event : Menu_Event;
                            Part  : Parts)
   is
   begin
      case This.Current_Part_Setting is
         when Project.Part_Patterns =>
            case Event.Kind is
            when Left_Press =>
               case This.Selected is
               when Tracks'First =>
                  null;
               when others =>
                  This.Selected := @ - 1;
               end case;

            when Right_Press =>
               case This.Selected is
               when Tracks'Last =>
                  null;
               when others =>
                  This.Selected := @ + 1;
               end case;

            when Up_Press =>
               case This.Selected is
               when 1 .. 8 =>
                  null;
               when 9 .. 16 =>
                  This.Selected := @ - 8;
               end case;

            when Down_Press =>
               case This.Selected is
               when 1 .. 8 =>
                  This.Selected := @ + 8;
               when 9 .. 16 =>
                  Next (This.Current_Part_Setting);
               end case;

            when A_Press =>
               Project.Pattern_Next (Part, This.Selected);

            when B_Press =>
               Project.Pattern_Prev (Part, This.Selected);

            when Slider_Touch =>
               null;
            end case;

         when Project.Part_Progression .. Project.Part_Link =>
            case Event.Kind is
               when Up_Press =>
                  Prev (This.Current_Part_Setting);
               when Down_Press =>
                  Next (This.Current_Part_Setting);
               when A_Press =>
                  case This.Current_Part_Setting is
                     when Project.Part_Progression =>
                        Project.Part_Chords_Next (Part);
                     when Project.Part_Link =>
                        Project.Toggle_Link (Part);
                     when others => null;
                  end case;
               when B_Press =>
                  case This.Current_Part_Setting is
                     when Project.Part_Progression =>
                        Project.Part_Chords_Prev (Part);
                     when Project.Part_Link =>
                        Project.Toggle_Link (Part);
                     when others => null;
                  end case;
               when others => null;
            end case;
      end case;
   end On_Part_Event;

   --------------------
   -- On_Chord_Event --
   --------------------

   procedure On_Chord_Event (This  : in out Pattern_Settings_Menu;
                             Event : Menu_Event;
                             Prog  : Chord_Progressions)
   is
      use WNM.Project;
      Id    : constant Project.Chord_Slot_Id := This.Selected_Chord;
      Len   : constant Project.Chord_Slot_Id :=
        WNM.Project.Progression_Length (Prog);
   begin
      case Event.Kind is
         when Left_Press =>
            if This.Current_Chord_Setting = Chord_Sub_Settings'First then
               if Id > Project.Chord_Slot_Id'First then
                  This.Selected_Chord := @ - 1;
                  This.Current_Chord_Setting := Chord_Sub_Settings'Last;
               end if;
            else
               Prev (This.Current_Chord_Setting);
            end if;

         when Right_Press =>
            if This.Current_Chord_Setting = Chord_Sub_Settings'Last then
               if Id <= Len then
                  This.Selected_Chord := @ + 1;
                  This.Current_Chord_Setting := Chord_Sub_Settings'First;
               end if;
            else
               Next (This.Current_Chord_Setting);
            end if;

         when Up_Press =>
            WNM.Project.Next_Value (Prog,
                                    This.Selected_Chord,
                                    This.Current_Chord_Setting);

         when Down_Press =>
            WNM.Project.Prev_Value (Prog,
                                    This.Selected_Chord,
                                    This.Current_Chord_Setting);

         when A_Press =>
            if Id > Len then
               WNM.Project.Increase_Progession_Length (Prog);
            end if;

         when B_Press =>
            if Id > Len then
               WNM.Project.Decrease_Progession_Length (Prog);
               This.Selected_Chord := @ - 1;
            end if;

         when Slider_Touch =>
            Project.Set (Prog,
                         This.Selected_Chord,
                         This.Current_Chord_Setting,
                         Event.Slider_Value);

      end case;
   end On_Chord_Event;

   --------------
   -- On_Event --
   --------------

   overriding
   procedure On_Event (This  : in out Pattern_Settings_Menu;
                       Event : Menu_Event)
   is
      Elt : constant Song_Element := Project.Editing_Song_Elt;
   begin
      case Elt is
         when Parts =>
            On_Part_Event (This, Event, Parts (Elt));
         when Chord_Progressions =>
            On_Chord_Event (This, Event, Chord_Progressions (Elt));
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
