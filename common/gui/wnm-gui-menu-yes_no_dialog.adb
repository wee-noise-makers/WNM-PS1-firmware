-------------------------------------------------------------------------------
--                                                                           --
--                              Wee Noise Maker                              --
--                                                                           --
--                     Copyright (C) 2020 Fabien Chouteau                    --
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

with WNM.Utils;
with WNM.GUI.Menu.Drawing;

package body WNM.GUI.Menu.Yes_No_Dialog is

   Yes_No_Dialog  : aliased Yes_No_Dialog_Window;
   Dialog_Title : String (1 .. Title_Max_Len) := (others => ' ');

   -----------------
   -- Push_Window --
   -----------------

   procedure Push_Window is
   begin
      Push (Yes_No_Dialog'Access);
   end Push_Window;

   ---------------
   -- Set_Title --
   ---------------

   procedure Set_Title (Title : String) is
   begin
      WNM.Utils.Copy_Str (Title, Dialog_Title);
   end Set_Title;

   ----------
   -- Draw --
   ----------

   overriding
   procedure Draw (This : in out Yes_No_Dialog_Window)
   is
   begin
      Drawing.Draw_Menu_Box (Dialog_Title, 0, 0);
      Drawing.Draw_Value ("-> " & (if This.Yes then "Yes" else "No"));
   end Draw;

   --------------
   -- On_Event --
   --------------

   overriding
   procedure On_Event
     (This  : in out Yes_No_Dialog_Window;
      Event : Menu_Event)
   is
   begin
      case Event.Kind is
         when A_Press =>
            if This.Yes then
               Menu.Pop (Exit_Value => Success);
            else
               Menu.Pop (Exit_Value => Failure);
            end if;
         when B_Press =>
            Menu.Pop (Exit_Value => Failure);
         when Right_Press | Left_Press =>
            This.Yes := not This.Yes;
         when others =>
            null;
      end case;
   end On_Event;

   ---------------
   -- On_Pushed --
   ---------------

   overriding
   procedure On_Pushed
     (This  : in out Yes_No_Dialog_Window)
   is
   begin
      This.Yes := False;
   end On_Pushed;

end WNM.GUI.Menu.Yes_No_Dialog;
