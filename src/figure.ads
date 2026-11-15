--  Figure and ground. Each animal is one tile region and belongs to exactly
--  one layer: even shapes are birds (layer 0), odd shapes are fish (layer 1).
--  Blend 0 paints the birds in ink and the fish as the gap. Blend 100 swaps
--  them. Replacing the blend with 100 minus itself is one swap; doing that
--  twice restores every animal.

with System;

package Figure is

   Shape_Count : constant := 8;

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
   function Last_Shape return Integer;
   function Last_Status return Status_Kind;

   function Shape_Layer (Shape : Shape_Index) return Integer;
   function Shape_Kind (Shape : Shape_Index) return Integer;
   function Shape_Ink (Shape : Shape_Index) return Integer;

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

   procedure Reset_Exported
     with Export, Convention => C, External_Name => "figure_reset";
   procedure Blend_Exported (Value : Integer)
     with Export, Convention => C, External_Name => "figure_blend";
   procedure Tap_Exported (Shape : Integer)
     with Export, Convention => C, External_Name => "figure_tap";
   procedure Undo_Exported
     with Export, Convention => C, External_Name => "figure_undo";

end Figure;
