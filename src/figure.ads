--  Liberation-style figure and ground. Flat triangles at the bottom
--  bend into birds further up. Dark birds and cream birds share every
--  edge. A uniform stage paints the same shape on every tile.

with System;

package Figure is

   Rows : constant := 9;
   Cols : constant := 7;

   J_Lo : constant := -1;
   J_Hi : constant := Rows;
   I_Lo : constant := -Rows - 2;
   I_Hi : constant := Cols + 1;

   Shape_Count : constant :=
     (J_Hi - J_Lo + 1) * (I_Hi - I_Lo + 1) * 2;
   Points : constant := 1597;

   subtype Shape_Index is Natural range 0 .. Shape_Count - 1;
   subtype Point_Index is Natural range 0 .. Points - 1;

   type Status_Kind is (Ok, Bad_Shape, Cannot_Undo);

   procedure Reset;
   procedure Set_Uniform (Value : Integer);
   procedure Tap (Shape : Integer);
   procedure Undo;

   function Morphing return Boolean;
   function Uniform return Integer;
   function Highlight return Integer;
   function Tap_Count return Integer;
   function Last_Shape return Integer;
   function Last_Status return Status_Kind;
   function Eye_Count return Natural;

   function Shape_Of (I, J, Side : Integer) return Shape_Index;
   function Shape_Kind (Shape : Shape_Index) return Integer;
   function Point_X (Shape : Shape_Index; Index : Point_Index) return Float;
   function Point_Y (Shape : Shape_Index; Index : Point_Index) return Float;
   function Eye_X (Index : Natural) return Float;
   function Eye_Y (Index : Natural) return Float;
   function Eye_Kind (Index : Natural) return Integer;

   function Curve_Len (Curve_Id : Natural) return Natural;
   function Curve_X (Curve_Id : Natural; Index : Natural) return Float;
   function Curve_Y (Curve_Id : Natural; Index : Natural) return Float;

   function Exported_Shapes return Integer
     with Export, Convention => C, External_Name => "figure_shapes";
   function Meta_Address return System.Address
     with Export, Convention => C, External_Name => "figure_meta";
   function Kind_Address return System.Address
     with Export, Convention => C, External_Name => "figure_kind";
   function Outline_Address return System.Address
     with Export, Convention => C, External_Name => "figure_outline_xy";
   function Eye_XY_Address return System.Address
     with Export, Convention => C, External_Name => "figure_eye_xy";
   function Eye_Kind_Address return System.Address
     with Export, Convention => C, External_Name => "figure_eye_kind";

   procedure Reset_Exported
     with Export, Convention => C, External_Name => "figure_reset";
   procedure Uniform_Exported (Value : Integer)
     with Export, Convention => C, External_Name => "figure_uniform";
   procedure Tap_Exported (Shape : Integer)
     with Export, Convention => C, External_Name => "figure_tap";
   procedure Undo_Exported
     with Export, Convention => C, External_Name => "figure_undo";

end Figure;
