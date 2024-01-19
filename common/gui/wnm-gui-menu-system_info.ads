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

package WNM.GUI.Menu.System_Info is

   procedure Push_Window;

private

   type Info_Kind is (Synth_CPU_Load,
                      Synth_Max_CPU_Load,
                      Synth_Missed_Deadlines,
                      DAC_Missed_Deadlines,
                      Input_Missed_Deadlines,
                      Prj_Last_Load_Size,
                      Prj_Last_Save_Size,
                      Raise_Exception);

   package Next_Info_Kind is new Enum_Next (Info_Kind, Wrap => True);
   use Next_Info_Kind;

   function Info_Kind_Count is new Enum_Count (Info_Kind);

   type Instance is new Menu_Window with record
      K : Info_Kind := Info_Kind'First;
   end record;

   overriding
   procedure Draw (This : in out Instance);

   overriding
   procedure On_Event (This  : in out Instance;
                       Event : Menu_Event);

   overriding
   procedure On_Pushed (This : in out Instance)
   is null;

   overriding
   procedure On_Focus (This       : in out Instance;
                       Exit_Value : Window_Exit_Value);

end WNM.GUI.Menu.System_Info;
