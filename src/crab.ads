--  A crab canon: one line, forward and back at once.
--  The page only draws what this package stores.

with System;

package Crab is

   Max_Tiles : constant := 11;
   Max_Notes : constant := 8;
   Pitch_Max : constant := 6;

   procedure Reset;

   procedure Clear_Letters;
   procedure Set_Letter (Index : Natural; Code : Natural);
   procedure Cycle_Letter (Index : Natural);
   procedure Set_Text (Text : String);

   function Letter (Index : Natural) return Natural;
   function Is_Palindrome return Boolean;

   procedure Cycle_Note (Index : Natural);
   function Note (Index : Natural) return Natural;
   function Mirror_Note (Index : Natural) return Natural;

   procedure Normalise (Text : String; Into : out String; Last : out Natural);
   procedure Reverse_Copy (Text : String; Into : out String);
   function Palindrome (Text : String) return Boolean;

   function Meta_Address return System.Address
     with Export, Convention => C, External_Name => "crab_meta";
   function Letter_Address return System.Address
     with Export, Convention => C, External_Name => "crab_letters";
   function Note_Address return System.Address
     with Export, Convention => C, External_Name => "crab_notes";
   function Mirror_Address return System.Address
     with Export, Convention => C, External_Name => "crab_mirrors";

   procedure Reset_Exported
     with Export, Convention => C, External_Name => "crab_reset";
   procedure Clear_Exported
     with Export, Convention => C, External_Name => "crab_clear";
   procedure Set_Letter_Exported (Index : Integer; Code : Integer)
     with Export, Convention => C, External_Name => "crab_set_letter";
   procedure Cycle_Letter_Exported (Index : Integer)
     with Export, Convention => C, External_Name => "crab_cycle_letter";
   procedure Cycle_Note_Exported (Index : Integer)
     with Export, Convention => C, External_Name => "crab_cycle_note";

end Crab;
