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

   Melody_Count : constant := 3;

   type Melody is array (1 .. Max_Notes) of Natural;

   procedure Retrograde (Source : Melody; Result : out Melody);

   function Shown_Length return Natural;

   Step_Ms : constant := 340;

   function Step_Milliseconds return Natural;
   --  Both voices share a step. The upper staff is the tune, left to right.
   --  The lower staff is that tune written backwards, so the backward voice
   --  walks it from the left as well. The markers meet on the middle step.
   function Play_Column (Voice : Natural; Beat : Natural) return Integer;

   procedure Set_Beat (Beat : Integer);
   procedure Cycle_Note (Index : Natural);
   procedure Select_Melody (Index : Natural);
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
   procedure Select_Melody_Exported (Index : Integer)
     with Export, Convention => C, External_Name => "crab_select_melody";
   procedure Set_Beat_Exported (Beat : Integer)
     with Export, Convention => C, External_Name => "crab_set_beat";

end Crab;
