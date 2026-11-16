--  Recursive structures. A stack of nested frames, a branching tree,
--  and the rabbit counts. The page only draws what this package stores.

with System;

package Recursion is

   Max_Depth   : constant := 6;
   Max_Tree    : constant := 10;
   Max_Terms   : constant := 11;
   Max_Segments : constant := 2047;
   Max_Dots    : constant := 89;

   subtype Depth_Range is Natural range 1 .. Max_Depth;
   subtype Tree_Range is Natural range 0 .. Max_Tree;

   type Status_Kind is (Ok, At_Bottom, At_Top, Full);

   procedure Reset;

   procedure Deeper;
   procedure Back;
   procedure Set_Tree (Depth : Integer);
   procedure Next_Rabbit;
   procedure Reset_Rabbits;

   function Frame_Depth return Depth_Range;
   function Tree_Depth return Tree_Range;
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
   function Dot_Count return Natural;
   function Dot_X (Index : Natural) return Integer;
   function Dot_Y (Index : Natural) return Integer;
   function Dot_R (Index : Natural) return Integer;
   function Dot_Color (Index : Natural) return Integer;
   function Last_Status return Status_Kind;

   function Meta_Address return System.Address
     with Export, Convention => C, External_Name => "recursion_meta";
   function Segment_Address return System.Address
     with Export, Convention => C, External_Name => "recursion_segments";
   function Dot_Address return System.Address
     with Export, Convention => C, External_Name => "recursion_dots";

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
