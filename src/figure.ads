--  Figure and ground. Every cell belongs to one shape, and every shape belongs
--  to one layer, so the two layers split the picture with nothing left over.
--  Blend 0 paints layer 0 in ink and layer 1 as the gap. Blend 100 swaps them.
--  A new blend of 100 minus the old one is one swap; doing that twice restores
--  every cell.

with System;

package Figure is

   Cols        : constant := 24;
   Rows        : constant := 16;
   Cell_Count  : constant := Cols * Rows;
   Shape_Count : constant := 6;

   subtype Cell_Index is Natural range 0 .. Cell_Count - 1;
   subtype Shape_Index is Natural range 0 .. Shape_Count - 1;

   type Status_Kind is (Ok, Bad_Shape, Cannot_Undo);

   procedure Reset;
   procedure Set_Blend (Value : Integer);
   procedure Tap (Shape : Integer);
   procedure Undo;

   function Blend return Integer;
   function Front_Layer return Integer;
   function Tap_Count return Integer;
   function Hidden_Shape return Integer;
   function Last_Found return Integer;
   function Last_Status return Status_Kind;

   function Cell_Shape (Index : Cell_Index) return Integer;
   function Cell_Layer (Index : Cell_Index) return Integer;
   function Cell_Ink (Index : Cell_Index) return Integer;

   function Shape_Layer (Shape : Shape_Index) return Integer;
   function Shape_Kind (Shape : Shape_Index) return Integer;
   function Shape_Head (Shape : Shape_Index) return Integer;
   function Shape_Dir_C (Shape : Shape_Index) return Integer;
   function Shape_Dir_R (Shape : Shape_Index) return Integer;

   function Exported_Cols return Integer
     with Export, Convention => C, External_Name => "figure_cols";
   function Exported_Rows return Integer
     with Export, Convention => C, External_Name => "figure_rows";
   function Exported_Shapes return Integer
     with Export, Convention => C, External_Name => "figure_shapes";
   function Meta_Address return System.Address
     with Export, Convention => C, External_Name => "figure_meta";
   function Cell_Shape_Address return System.Address
     with Export, Convention => C, External_Name => "figure_cell_shape";
   function Cell_Layer_Address return System.Address
     with Export, Convention => C, External_Name => "figure_cell_layer";
   function Cell_Ink_Address return System.Address
     with Export, Convention => C, External_Name => "figure_cell_ink";
   function Shape_Layer_Address return System.Address
     with Export, Convention => C, External_Name => "figure_shape_layer";
   function Shape_Kind_Address return System.Address
     with Export, Convention => C, External_Name => "figure_shape_kind";
   function Shape_Head_Address return System.Address
     with Export, Convention => C, External_Name => "figure_shape_head";
   function Shape_Dir_C_Address return System.Address
     with Export, Convention => C, External_Name => "figure_shape_dir_c";
   function Shape_Dir_R_Address return System.Address
     with Export, Convention => C, External_Name => "figure_shape_dir_r";

   procedure Reset_Exported
     with Export, Convention => C, External_Name => "figure_reset";
   procedure Blend_Exported (Value : Integer)
     with Export, Convention => C, External_Name => "figure_blend";
   procedure Tap_Exported (Shape : Integer)
     with Export, Convention => C, External_Name => "figure_tap";
   procedure Undo_Exported
     with Export, Convention => C, External_Name => "figure_undo";

end Figure;
