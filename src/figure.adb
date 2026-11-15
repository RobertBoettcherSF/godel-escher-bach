package body Figure is

   type Snap is record
      Mix   : Integer := 0;
      Taps  : Integer := 0;
      Found : Integer := 0;
      Which : Integer := -1;
      Grown : Integer := 100;
   end record;

   Max_Hist : constant := 24;
   Points   : constant := 3 * Samples;
   Floats   : constant := Points * 2;

   --  Right-pointing isosceles triangle. The light bird is its mirror
   --  across the vertical tail. The belly curve is the glide of the back
   --  curve, so neighbouring birds share every slanted edge.
   Wing    : constant Float := 240.0;
   Span    : constant Float := 150.0;
   Half    : constant Float := 75.0;
   Shift_X : constant Float := 260.0;
   Shift_Y : constant Float := 40.0;
   Out_X   : constant Float := 0.298274993;
   Out_Y   : constant Float := 0.954479978;

   Mix      : Integer     := 0;
   Taps     : Integer     := 0;
   Found    : Integer     := 0;
   Which    : Integer     := -1;
   Grown    : Integer     := 100;
   Err      : Status_Kind := Ok;
   Hist     : array (1 .. Max_Hist) of Snap := (others => (0, 0, 0, -1, 100));
   Hist_Len : Natural     := 0;

   Meta       : array (1 .. 9) of Integer := (others => 0);
   Layer_Slot : array (Shape_Index) of Integer := (others => 0);
   Kind_Slot  : array (Shape_Index) of Integer := (others => 0);
   Ink_Slot   : array (Shape_Index) of Integer := (others => 0);
   Counts     : array (Shape_Index) of Integer := (others => 0);
   XY         : array (0 .. Shape_Count * Floats - 1) of Float := (others => 0.0);

   function Blend return Integer is (Mix);

   function Grow return Integer is (Grown);

   function Front_Layer return Integer is
     (if Mix < 50 then 0 else 1);

   function Tap_Count return Integer is (Taps);

   function Last_Found return Integer is (Found);

   function Last_Shape return Integer is (Which);

   function Last_Status return Status_Kind is (Err);

   function Shape_Layer (Shape : Shape_Index) return Integer is
     (Shape mod 2);

   function Shape_Kind (Shape : Shape_Index) return Integer is
     (Shape mod 2);

   function Ink_Of (Layer : Integer) return Integer is
   begin
      if Layer = 0 then
         return 255 - (255 * Mix) / 100;
      end if;
      return (255 * Mix) / 100;
   end Ink_Of;

   function Shape_Ink (Shape : Shape_Index) return Integer is
     (Ink_Of (Shape_Layer (Shape)));

   function Hidden_Shape return Integer is
   begin
      for Shape in Shape_Index loop
         if Shape_Layer (Shape) /= Front_Layer then
            return Shape;
         end if;
      end loop;
      return 0;
   end Hidden_Shape;

   function Point_Count (Shape : Shape_Index) return Natural is
     (Natural (Counts (Shape)));

   function Point_X (Shape : Shape_Index; Index : Natural) return Float is
     (XY (Shape * Floats + Index * 2));

   function Point_Y (Shape : Shape_Index; Index : Natural) return Float is
     (XY (Shape * Floats + Index * 2 + 1));

   function Status_Code (Status : Status_Kind) return Integer is
   begin
      case Status is
         when Ok =>
            return 0;
         when Bad_Shape =>
            return 2;
         when Cannot_Undo =>
            return 5;
      end case;
   end Status_Code;

   function Bump (U, Center, Width, Height : Float) return Float is
      X : constant Float := (U - Center) / Width;
      Z : Float;
   begin
      if X <= -1.0 or else X >= 1.0 then
         return 0.0;
      end if;
      Z := 1.0 - X * X;
      return Height * Z * Z;
   end Bump;

   function Back_Offset (T : Float) return Float is
     (Bump (T, 0.15, 0.10, 14.0)
      + Bump (T, 0.36, 0.16, 42.0)
      + Bump (T, 0.68, 0.10, 36.0)
      + Bump (T, 0.90, 0.055, 14.0));

   procedure Put
     (Shape : Shape_Index; Index : Natural; X, Y : Float)
   is
      Base : constant Natural := Shape * Floats + Index * 2;
   begin
      XY (Base) := X;
      XY (Base + 1) := Y;
   end Put;

   procedure Build
     (Shape : Shape_Index; Ox, Oy : Float; Mirror : Boolean)
   is
      Scale : constant Float := Float (Grown) / 100.0;
      Slot  : Natural := 0;

      procedure Keep (Local_X, Local_Y : Float) is
         X : Float := Ox + Local_X;
      begin
         if Mirror then
            X := Ox - Local_X;
         end if;
         Put (Shape, Slot, X, Oy + Local_Y);
         Slot := Slot + 1;
      end Keep;

      procedure Upper (T : Float; Ux, Uy : out Float) is
         Off : constant Float := Back_Offset (T) * Scale;
      begin
         Ux := T * Wing + Out_X * Off;
         Uy := Span + T * (Half - Span) + Out_Y * Off;
      end Upper;
   begin
      for I in 0 .. Samples loop
         declare
            T, Ux, Uy : Float;
         begin
            T := Float (I) / Float (Samples);
            Upper (T, Ux, Uy);
            Keep (Ux, Uy);
         end;
      end loop;
      for I in 1 .. Samples loop
         declare
            T, Ux, Uy : Float;
         begin
            T := Float (I) / Float (Samples);
            Upper (T, Ux, Uy);
            Keep (Wing - Ux, Uy - Half);
         end;
      end loop;
      for I in 1 .. Samples - 1 loop
         Keep (0.0, Float (I) / Float (Samples) * Span);
      end loop;
      Counts (Shape) := Integer (Slot);
   end Build;

   procedure Refresh is
   begin
      for J in J0 .. J1 loop
         for I in I0 .. I1 loop
            declare
               Cell : constant Integer :=
                 (I - I0) + (J - J0) * (I1 - I0 + 1);
               Ox   : constant Float :=
                 Shift_X + Float (I - J) * Wing;
               Oy   : constant Float :=
                 Shift_Y + Float (I + J) * Half;
               Right : constant Shape_Index := Shape_Index (Cell * 2);
               Left  : constant Shape_Index := Shape_Index (Cell * 2 + 1);
            begin
               Build (Right, Ox, Oy, False);
               Build (Left, Ox, Oy, True);
            end;
         end loop;
      end loop;
      for Shape in Shape_Index loop
         Layer_Slot (Shape) := Shape_Layer (Shape);
         Kind_Slot (Shape) := Shape_Kind (Shape);
         Ink_Slot (Shape) := Shape_Ink (Shape);
      end loop;
      Meta (1) := Mix;
      Meta (2) := Front_Layer;
      Meta (3) := Taps;
      Meta (4) := Hidden_Shape;
      Meta (5) := Found;
      Meta (6) := Status_Code (Err);
      Meta (7) := Shape_Count;
      Meta (8) := Which;
      Meta (9) := Grown;
   end Refresh;

   procedure Remember is
   begin
      if Hist_Len = Max_Hist then
         for I in 1 .. Max_Hist - 1 loop
            Hist (I) := Hist (I + 1);
         end loop;
         Hist_Len := Max_Hist - 1;
      end if;
      Hist_Len := Hist_Len + 1;
      Hist (Hist_Len) := (Mix, Taps, Found, Which, Grown);
   end Remember;

   procedure Reset is
   begin
      Mix := 0;
      Taps := 0;
      Found := 0;
      Which := -1;
      Grown := 100;
      Err := Ok;
      Hist_Len := 0;
      Remember;
      Refresh;
   end Reset;

   procedure Set_Blend (Value : Integer) is
   begin
      if Value < 0 then
         Mix := 0;
      elsif Value > 100 then
         Mix := 100;
      else
         Mix := Value;
      end if;
      Err := Ok;
      Refresh;
   end Set_Blend;

   procedure Set_Grow (Value : Integer) is
   begin
      if Value < 0 then
         Grown := 0;
      elsif Value > 100 then
         Grown := 100;
      else
         Grown := Value;
      end if;
      Err := Ok;
      Refresh;
   end Set_Grow;

   procedure Tap (Shape : Integer) is
   begin
      if Shape < 0 or else Shape >= Shape_Count then
         Err := Bad_Shape;
         Refresh;
         return;
      end if;
      Which := Shape;
      if Shape_Layer (Shape_Index (Shape)) /= Front_Layer then
         Found := 1;
      else
         Found := 0;
      end if;
      Mix := 100 - Mix;
      Taps := Taps + 1;
      Err := Ok;
      Remember;
      Refresh;
   end Tap;

   procedure Undo is
   begin
      if Hist_Len <= 1 then
         Err := Cannot_Undo;
         Refresh;
         return;
      end if;
      Hist_Len := Hist_Len - 1;
      Mix := Hist (Hist_Len).Mix;
      Taps := Hist (Hist_Len).Taps;
      Found := Hist (Hist_Len).Found;
      Which := Hist (Hist_Len).Which;
      Grown := Hist (Hist_Len).Grown;
      Err := Ok;
      Refresh;
   end Undo;

   function Exported_Shapes return Integer is (Shape_Count);
   function Meta_Address return System.Address is (Meta'Address);
   function Shape_Layer_Address return System.Address is (Layer_Slot'Address);
   function Shape_Kind_Address return System.Address is (Kind_Slot'Address);
   function Shape_Ink_Address return System.Address is (Ink_Slot'Address);
   function Outline_Count_Address return System.Address is (Counts'Address);
   function Outline_XY_Address return System.Address is (XY'Address);
   function Outline_Stride return Integer is (Floats);

   procedure Reset_Exported is
   begin
      Reset;
   end Reset_Exported;

   procedure Blend_Exported (Value : Integer) is
   begin
      Set_Blend (Value);
   end Blend_Exported;

   procedure Grow_Exported (Value : Integer) is
   begin
      Set_Grow (Value);
   end Grow_Exported;

   procedure Tap_Exported (Shape : Integer) is
   begin
      Tap (Shape);
   end Tap_Exported;

   procedure Undo_Exported is
   begin
      Undo;
   end Undo_Exported;

begin
   Reset;
end Figure;
