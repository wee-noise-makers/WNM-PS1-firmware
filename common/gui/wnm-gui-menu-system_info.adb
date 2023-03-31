-------------------------------------------------------------------------------
--                                                                           --
--                              Wee Noise Maker                              --
--                                                                           --
--                     Copyright (C) 2023 Fabien Chouteau                  --
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

with WNM.GUI.Menu.Drawing;
with WNM.Synth;
with WNM.Project.Library;

package body WNM.GUI.Menu.System_Info is

   Singleton : aliased Instance;

   -----------------
   -- Push_Window --
   -----------------

   procedure Push_Window is
   begin
      Push (Singleton'Access);
   end Push_Window;

   ----------
   -- Draw --
   ----------

   overriding
   procedure Draw (This : in out Instance) is
   begin
      Drawing.Draw_Menu_Box ("System info",
                             Info_Kind_Count,
                             Info_Kind'Pos (This.K));

      case This.K is

      when Synth_CPU_Load =>
            Drawing.Draw_Title ("Synth CPU Load", "");
            Drawing.Draw_Value (Img (Synth.Last_CPU_Load));

         when Synth_Max_CPU_Load =>
            Drawing.Draw_Title ("Synth Max CPU Load", "");
            Drawing.Draw_Value (Img (Synth.Max_CPU_Load));

         when Synth_Missed_Deadlines =>
            Drawing.Draw_Title ("Synth Miss DL", "");
            Drawing.Draw_Value (Synth.Missed_Deadlines'Img);

         when Prj_Last_Load_Size =>
            Drawing.Draw_Title ("Size of last loaded", "project");
            Drawing.Draw_Value (Project.Library.Last_Loaded_Size'Img);

         when Prj_Last_Save_Size =>
            Drawing.Draw_Title ("Size of last saved", "project");
            Drawing.Draw_Value (Project.Library.Last_Saved_Size'Img);
      end case;
   end Draw;

   --------------
   -- On_Event --
   --------------

   overriding
   procedure On_Event (This  : in out Instance;
                       Event : Menu_Event)
   is
   begin
      case Event.Kind is
         when Left_Press =>
            case This.K is
               when Synth_Max_CPU_Load =>
                  Synth.Clear_Max_CPU_Load;
               when Synth_Missed_Deadlines =>
                  Synth.Clear_Missed_Deadlines;
               when others =>
                  null;
            end case;

         when Right_Press =>
            Menu.Pop (Exit_Value => Failure);

         when Encoder_Left =>

            if Event.Value > 0 then
               Next (This.K);
            elsif Event.Value < 0 then
               Prev (This.K);
            end if;

         when others =>
            null;
      end case;
   end On_Event;

end WNM.GUI.Menu.System_Info;
