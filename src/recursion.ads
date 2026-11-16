--  Recursive structures. A stack of nested frames, a branching tree,
--  and the rabbit counts. The page only draws what this package stores.

with System;

package Recursion is

   --  Far past any visit. Deeper, Grow and Next saturate here.
   Depth_Ceiling : constant := 1_000_000;
   --  Past this many splits the picture zooms into one branch.
   Visible_Cap   : constant := 10;
   Max_Digits    : constant := 256;
   Max_Segments  : constant := 2047;
   Max_Dots      : constant := 400;

   type Status_Kind is (Ok, At_Bottom, At_Top, Full);

   procedure Reset;

   procedure Deeper;
   procedure Back;
   procedure Set_Tree (Depth : Integer);
   procedure Next_Rabbit;
   procedure Reset_Rabbits;

   function Frame_Depth return Natural;
   function Tree_Depth return Natural;
   function Tree_Visible return Natural;
   function Segment_Count return Natural;
   function Segment_X1 (Index : Natural) return Integer;
   function Segment_Y1 (Index : Natural) return Integer;
   function Segment_X2 (Index : Natural) return Integer;
   function Segment_Y2 (Index : Natural) return Integer;
   function Segment_Level (Index : Natural) return Integer;

   function Rabbit_Terms return Natural;
   function Rabbit_Value return Natural;
   function Rabbit_Older return Natural;
   function Rabbit_Newer return Natural;
   function Rabbit_Value_Text return String;
   function Rabbit_Older_Text return String;
   function Rabbit_Newer_Text return String;
   function Rabbit_Unit_Exp return Natural;
   function Dot_Count return Natural;
   function Dot_X (Index : Natural) return Integer;
   function Dot_Y (Index : Natural) return Integer;
   function Dot_R (Index : Natural) return Integer;
   function Dot_Color (Index : Natural) return Integer;
   function Dot_Pile (Index : Natural) return Integer;
   function Last_Status return Status_Kind;

   function Meta_Address return System.Address
     with Export, Convention => C, External_Name => "recursion_meta";
   function Segment_Address return System.Address
     with Export, Convention => C, External_Name => "recursion_segments";
   function Dot_Address return System.Address
     with Export, Convention => C, External_Name => "recursion_dots";
   function Digit_Address return System.Address
     with Export, Convention => C, External_Name => "recursion_digits";

   procedure Reset_Exported
     with Export, Convention => C, External_Name => "recursion_reset";
   procedure Deeper_Exported
     with Export, Convention => C, External_Name => "recursion_deeper";
   procedure Back_Exported
     with Export, Convention => C, External_Name => "recursion_back";
   procedure Tree_Exported (Depth : Integer)
     with Export, Convention => C, External_Name => "recursion_tree";
   procedure Next_Exported
     with Export, Convention => C, External_Name => "recursion_next";
   procedure Rabbits_Reset_Exported
     with Export, Convention => C, External_Name => "recursion_rabbits_reset";

end Recursion;
