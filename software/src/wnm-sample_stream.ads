-------------------------------------------------------------------------------
--                                                                           --
--                              Wee Noise Maker                              --
--                                                                           --
--                     Copyright (C) 2017 Fabien Chouteau                    --
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

with WNM.File_System;

with WNM.Audio;

package WNM.Sample_Stream is
   pragma Elaborate_Body;

   type Stream_Track is (Always_On, ST_1, ST_2, ST_3, ST_4, ST_5, ST_6, ST_7,
                         ST_8, ST_9, ST_10, ST_11, ST_12, ST_13, ST_14, ST_15,
                         ST_16);

   function To_Stream_Track (T : Tracks) return Stream_Track;
   function To_Track (ST : Stream_Track) return Tracks
     with Pre => ST /= Always_On;

   procedure Assign_Sample (Track    : Stream_Track;
                            Filepath : String);

   procedure Start (Track       : Stream_Track;
                    Start_Point : Natural;
                    End_Point   : Natural;
                    Looping     : Boolean);

   procedure Next_Buffer (Track   :     Stream_Track;
                          Buffer  : out Audio.Mono_Buffer;
                          Success : out Boolean);

   procedure Copy_File (Srcpath  : String;
                        From, To : Natural;
                        Dstpath  : String);

private

   type Stream_State is (Unused, Assigned, Running);

   type Stream_Info is record
      State       : Stream_State := Unused;
      Cursor      : Natural;
      Start_Point : Natural;
      End_Point   : Natural;
      Looping     : Boolean;
      FD          : aliased File_System.File_Descriptor;
   end record;

   Streams : array (Stream_Track) of Stream_Info;

end WNM.Sample_Stream;
