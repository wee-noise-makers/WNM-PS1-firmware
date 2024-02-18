-------------------------------------------------------------------------------
--                                                                           --
--                              Wee Noise Maker                              --
--                                                                           --
--                     Copyright (C) 2022 Fabien Chouteau                    --
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

with WNM.Step_Event_Broadcast;
with WNM.Part_Event_Broadcast;
with WNM.Song_Start_Broadcast;

package body WNM.Project.Song_Part_Sequencer is

   procedure Step_Callback;
   package Step_Listener
   is new Step_Event_Broadcast.Register (Step_Callback'Access);
   pragma Unreferenced (Step_Listener);

   procedure Song_Start_Callback;
   package Song_Start_Listener
   is new Song_Start_Broadcast.Register (Song_Start_Callback'Access);
   pragma Unreferenced (Song_Start_Listener);

   -------------------------
   -- Song_Start_Callback --
   -------------------------

   procedure Song_Start_Callback is
   begin
      G_Play_State.Origin := G_Project.Part_Origin;
      G_Play_State.Playing_Part := G_Play_State.Origin;
      G_Play_State.Part_Steps_Count := 0;

      --  Broadcast the change of part
      WNM.Part_Event_Broadcast.Broadcast;
   end Song_Start_Callback;

   -------------------
   -- Step_Callback --
   -------------------

   procedure Step_Callback is
      Current_Part : constant Parts := G_Play_State.Playing_Part;
      New_Part : Parts;
   begin
      G_Play_State.Part_Steps_Count := @ + 1; -- The Step we're about to play

      if G_Play_State.Part_Steps_Count >
        Natural (G_Project.Parts (G_Play_State.Playing_Part).Len)
      then
         if G_Project.Part_Origin /= G_Play_State.Origin then
            --  New origin part, play this next
            G_Play_State.Origin := G_Project.Part_Origin;
            New_Part := G_Play_State.Origin;

         elsif G_Project.Parts (G_Play_State.Playing_Part).Link then
            --  There's a link to the next part
            New_Part := G_Play_State.Playing_Part + 1;
         else
            --  Start back to origin part
            New_Part := G_Project.Part_Origin;
         end if;

         --  We're going to play the first step of the new part
         G_Play_State.Part_Steps_Count := 1;

         if New_Part /= Current_Part then
            G_Play_State.Playing_Part := New_Part;
            --  Broadcast the change of part
            WNM.Part_Event_Broadcast.Broadcast;
         end if;
      end if;
   end Step_Callback;

   -------------
   -- Playing --
   -------------

   function Playing return Parts
   is (G_Play_State.Playing_Part);

   -----------
   -- Muted --
   -----------

   function Muted (T : Tracks) return Boolean
   is (G_Project.Parts (G_Play_State.Playing_Part).Track_Mute (T));

end WNM.Project.Song_Part_Sequencer;
