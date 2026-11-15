--  Figure and ground. One bird shape tiles the frame.
--  Even shapes are dark birds flying right (layer 0). Odd shapes are the
--  same bird mirrored, light, flying left (layer 1). They meet on every
--  edge. Grow 0 is the plain triangle; grow 100 is the bird. A swap
--  replaces the blend with 100 minus itself, so two swaps restore it.

with System;

package Figure is

   I0 : constant := -1;
   I1 : constant := 4;
   J0 : constant := -2;
   J1 : constant := 5;

   Shape_Count : constant := (I1 - I0 + 1) * (J1 - J0 + 1) * 2;
   Samples     : constant := 48;

   subtype Shape_Index is Natural range 0 .. Shape_Count - 1;

   type Status_Kind is (Ok, Bad_Shape, Cannot_Undo);

   procedure Reset;
   procedure Set_Blend (Value : Integer);
   procedure Set_Grow (Value : Integer);
   procedure Tap (Shape : Integer);
   procedure Undo;

   function Blend return Integer;
   function Grow return Integer;
   function Front_Layer return Integer;
   function Tap_Count return Integer;
   function Hidden_Shape return Integer;
   function Last_Found return Integer;
   function Last_Shape return Integer;
   function Last_Status return Status_Kind;

   function Shape_Layer (Shape : Shape_Index) return Integer;
   function Shape_Kind (Shape : Shape_Index) return Integer;
   function Shape_Ink (Shape : Shape_Index) return Integer;

   function Point_Count (Shape : Shape_Index) return Natural;
   function Point_X (Shape : Shape_Index; Index : Natural) return Float;
   function Point_Y (Shape : Shape_Index; Index : Natural) return Float;

   function Exported_Shapes return Integer
     with Export, Convention => C, External_Name => "figure_shapes";
   function Meta_Address return System.Address
     with Export, Convention => C, External_Name => "figure_meta";
   function Shape_Layer_Address return System.Address
     with Export, Convention => C, External_Name => "figure_shape_layer";
   function Shape_Kind_Address return System.Address
     with Export, Convention => C, External_Name => "figure_shape_kind";
   function Shape_Ink_Address return System.Address
     with Export, Convention => C, External_Name => "figure_shape_ink";
   function Outline_Count_Address return System.Address
     with Export, Convention => C, External_Name => "figure_outline_count";
   function Outline_XY_Address return System.Address
     with Export, Convention => C, External_Name => "figure_outline_xy";
   function Outline_Stride return Integer
     with Export, Convention => C, External_Name => "figure_outline_stride";

   procedure Reset_Exported
     with Export, Convention => C, External_Name => "figure_reset";
   procedure Blend_Exported (Value : Integer)
     with Export, Convention => C, External_Name => "figure_blend";
   procedure Grow_Exported (Value : Integer)
     with Export, Convention => C, External_Name => "figure_grow";
   procedure Tap_Exported (Shape : Integer)
     with Export, Convention => C, External_Name => "figure_tap";
   procedure Undo_Exported
     with Export, Convention => C, External_Name => "figure_undo";

end Figure;
