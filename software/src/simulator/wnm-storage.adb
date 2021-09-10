with Ada.Text_IO; use Ada.Text_IO;

with Littlefs; use Littlefs;
with Interfaces.C; use Interfaces.C;
with Interfaces; use Interfaces;

with GNAT.OS_Lib; use GNAT.OS_Lib;

with WNM_Sim;
with System;

package body WNM.Storage is

   type LFS_Config_Access is access all Standard.Littlefs.LFS_Config;

   Config : LFS_Config_Access := null;
   FD : aliased GNAT.OS_Lib.File_Descriptor;

   package FD_Backend is
      function Create (FD : aliased GNAT.OS_Lib.File_Descriptor)
                       return LFS_Config_Access;

   end FD_Backend;

   package body FD_Backend is

      function Read (C      : access constant LFS_Config;
                     Block  : LFS_Block;
                     Off    : LFS_Offset;
                     Buffer : System.Address;
                     Size   : LFS_Size)
                     return int
        with Convention => C;

      function Prog (C      : access constant LFS_Config;
                     Block  : LFS_Block;
                     Off    : LFS_Offset;
                     Buffer : System.Address;
                     Size   : LFS_Size)
                     return int
        with Convention => C;
      function Erase (C     : access constant LFS_Config;
                      Block : LFS_Block)
                      return int
        with Convention => C;
      function Sync (C : access constant LFS_Config) return int
        with Convention => C;

      ----------
      -- Read --
      ----------

      function Read (C      : access constant LFS_Config;
                     Block  : LFS_Block;
                     Off    : LFS_Offset;
                     Buffer : System.Address;
                     Size   : LFS_Size)
                     return int
      is
         Offset : constant LFS_Offset := Off + C.Block_Size * LFS_Size (Block);
         FD : GNAT.OS_Lib.File_Descriptor with Address => C.Context;
      begin
         GNAT.OS_Lib.Lseek (FD     => FD,
                            offset => Long_Integer (Offset),
                            origin => GNAT.OS_Lib.Seek_Set);

         if GNAT.OS_Lib.Read (FD, Buffer, Integer (Size)) = Integer (Size) then
            return 0;
         else
            return LFS_ERR_IO;
         end if;
      end Read;

      ----------
      -- Prog --
      ----------

      function Prog (C      : access constant LFS_Config;
                     Block  : LFS_Block;
                     Off    : LFS_Offset;
                     Buffer : System.Address;
                     Size   : LFS_Size)
                     return int
      is
         Offset : constant LFS_Offset := Off + C.Block_Size * LFS_Size (Block);
         FD : GNAT.OS_Lib.File_Descriptor with Address => C.Context;
      begin
         GNAT.OS_Lib.Lseek (FD     => FD,
                            offset => Long_Integer (Offset),
                            origin => GNAT.OS_Lib.Seek_Set);

         if GNAT.OS_Lib.Write (FD, Buffer, Integer (Size)) = Integer (Size) then
            return 0;
         else
            return LFS_ERR_IO;
         end if;
      end Prog;

      -----------
      -- Erase --
      -----------

      function Erase (C : access constant LFS_Config;
                      Block : LFS_Block)
                      return int
      is
         Offset : constant LFS_Offset := C.Block_Size * LFS_Size (Block);
         FD : GNAT.OS_Lib.File_Descriptor with Address => C.Context;

         Zeros : constant array (1 .. C.Block_Size) of Unsigned_8 :=
           (others => 0);

         Size : constant Integer := Integer (C.Block_Size);
      begin
         GNAT.OS_Lib.Lseek (FD     => FD,
                            offset => Long_Integer (Offset),
                            origin => GNAT.OS_Lib.Seek_Set);

         if GNAT.OS_Lib.Write (FD, Zeros'Address, Size) = Size then
            return 0;
         else
            return LFS_ERR_IO;
         end if;
      end Erase;

      ----------
      -- Sync --
      ----------

      function Sync (C : access constant LFS_Config) return int is
         pragma Unreferenced (C);
      begin
         return 0;
      end Sync;

      ------------
      -- Create --
      ------------

      function Create (FD : aliased GNAT.OS_Lib.File_Descriptor)
                       return LFS_Config_Access
      is
         Ret : constant LFS_Config_Access := new LFS_Config;
      begin
         Ret.Context := FD'Address;
         Ret.Read := Read'Access;
         Ret.Prog := Prog'Access;
         Ret.Erase := Erase'Access;
         Ret.Sync := Sync'Access;
         Ret.Read_Size := 2048;
         Ret.Prog_Size := 2048;
         Ret.Block_Size := 2048;

         Ret.Block_Count :=
           LFS_Size (GNAT.OS_Lib.File_Length (FD)) / Ret.Block_Size;

         Ret.Block_Cycles := 700;
         Ret.Cache_Size := Ret.Block_Size;
         Ret.Lookahead_Size := Ret.Block_Size;
         Ret.Read_Buffer := System.Null_Address;
         Ret.Prog_Buffer := System.Null_Address;
         Ret.Lookahead_Buffer := System.Null_Address;
         Ret.Name_Max := 0;
         Ret.File_Max := 0;
         Ret.Attr_Max := 0;
         return Ret;
      end Create;
   end FD_Backend;

   --------------------
   -- Get_LFS_Config --
   --------------------

   function Get_LFS_Config return not null access Littlefs.LFS_Config is
   begin
      return Config;
   end Get_LFS_Config;

begin

   if WNM_Sim.Switch_Storage_Image /= null
     and then
       WNM_Sim.Switch_Storage_Image.all /= ""
   then

      declare
         Image_Path : constant String := WNM_Sim.Switch_Storage_Image.all;
      begin
         --  The image file should exists and be writable

         if not Is_Regular_File (Image_Path) then
            Put_Line ("Image file '" & Image_Path & "' does not exists");
            GNAT.OS_Lib.OS_Exit (1);
         elsif not Is_Owner_Writable_File (Image_Path) then
            Put_Line ("Image file '" & Image_Path & "' is not writable");
            GNAT.OS_Lib.OS_Exit (1);
         else
            Put_Line ("Open image file '" & Image_Path & "'...");
            FD := Open_Read_Write (Image_Path, Binary);
         end if;

         if FD = Invalid_FD then
            Put_Line ("Cannot open image file '" & Image_Path & "': " &
                        GNAT.OS_Lib.Errno_Message);
            OS_Exit (1);
         end if;

         if File_Length (FD) /= WNM.Storage.Size then
            Put_Line ("Invalid size for image file '" & Image_Path & "'");
            OS_Exit (1);
         end if;
      end;
   else
      Put_Line ("--img required.");
      OS_Exit (1);
   end if;

   Config := FD_Backend.Create (FD);
end WNM.Storage;