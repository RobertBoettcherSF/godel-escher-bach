package body Figure is

   type Snap is record
      Mix   : Integer := 0;
      Taps  : Integer := 0;
      Found : Integer := 0;
      Which : Integer := -1;
   end record;

   Max_Hist : constant := 24;

   Mix      : Integer     := 0;
   Taps     : Integer     := 0;
   Found    : Integer     := 0;
   Which    : Integer     := -1;
   Err      : Status_Kind := Ok;
   Hist     : array (1 .. Max_Hist) of Snap := (others => (0, 0, 0, -1));
   Hist_Len : Natural     := 0;

   Meta       : array (1 .. 8) of Integer := (others => 0);
   Layer_Slot : array (Shape_Index) of Integer := (others => 0);
   Kind_Slot  : array (Shape_Index) of Integer := (others => 0);
   Ink_Slot   : array (Shape_Index) of Integer := (others => 0);

   --  Lattice. A 2 by 2 block of rectangles. The right edge is the left edge
   --  translated by the width, and the bottom edge is the top edge translated
   --  by the height. Inside each rectangle one curve separates the bird from
   --  the fish, so the fish is the space the bird does not take.
   Cell_W    : constant := 720;
   Cell_H    : constant := 460;
   Samples   : constant := 32;
   XY        : array (0 .. Shape_Count * Max_Outline * 2 - 1) of Integer :=
     (others => 0);
   Counts    : array (Shape_Index) of Integer := (others => 0);
   Built     : Boolean := False;

   function Tri (U, Center, Width, Height : Integer) return Integer is
      D : constant Integer := abs (U - Center);
   begin
      if D >= Width then
         return 0;
      end if;
      return Height * (Width - D) / Width;
   end Tri;

   function Tail_X (Y : Integer) return Integer is
      U : constant Integer := Y * 1000 / Cell_H;
   begin
      return Tri (U, 420, 80, 170) + Tri (U, 580, 80, 170) - Tri (U, 500, 50, 20);
   end Tail_X;

   function Top_Y (X : Integer) return Integer is
      U : constant Integer := X * 1000 / Cell_W;
   begin
      return -(Tri (U, 160, 70, 34) + Tri (U, 340, 60, 26) + Tri (U, 700, 60, 78));
   end Top_Y;

   function Mid_X (Y : Integer) return Integer is
      U : constant Integer := Y * 1000 / Cell_H;
   begin
      return (Cell_W * 56) / 100 + Tri (U, 300, 60, 58) - Tri (U, 620, 140, 70);
   end Mid_X;

   procedure Add_Point (Shape : Shape_Index; X, Y : Integer) is
      Slot : Integer;
   begin
      if Counts (Shape) >= Max_Outline then
         return;
      end if;
      Slot := Integer (Shape) * Max_Outline * 2 + Counts (Shape) * 2;
      XY (Slot) := X;
      XY (Slot + 1) := Y;
      Counts (Shape) := Counts (Shape) + 1;
   end Add_Point;

   procedure Build_Outlines is
      type Sample_Array is array (0 .. Samples) of Integer;
      Top_X, Top_YV, Bot_X, Bot_Y, Mid_XV, Mid_Y : Sample_Array;
      Left_X, Left_Y, Right_X, Right_Y           : Sample_Array;
   begin
      for Shape in Shape_Index loop
         Counts (Shape) := 0;
      end loop;
      for I in 0 .. Samples loop
         declare
            X : constant Integer := Cell_W * I / Samples;
            Y : constant Integer := Cell_H * I / Samples;
         begin
            Top_X (I) := X;
            Top_YV (I) := Top_Y (X);
            Bot_X (I) := X;
            Bot_Y (I) := Cell_H + Top_Y (X);
            Mid_XV (I) := Mid_X (Y);
            Mid_Y (I) := Y;
            Left_X (I) := Tail_X (Y);
            Left_Y (I) := Y;
            Right_X (I) := Cell_W + Tail_X (Y);
            Right_Y (I) := Y;
         end;
      end loop;

      for Row in 0 .. 1 loop
         for Col in 0 .. 1 loop
            declare
               Bird : constant Shape_Index := Shape_Index ((Row * 2 + Col) * 2);
               Fish : constant Shape_Index := Shape_Index (Integer (Bird) + 1);
               DX   : constant Integer := Col * Cell_W;
               DY   : constant Integer := Row * Cell_H;
               Gate : constant Integer := Mid_X (0);
            begin
               for I in 0 .. Samples loop
                  if Top_X (I) <= Gate then
                     Add_Point (Bird, Top_X (I) + DX, Top_YV (I) + DY);
                  end if;
                  if Top_X (I) >= Gate then
                     Add_Point (Fish, Top_X (I) + DX, Top_YV (I) + DY);
                  end if;
               end loop;
               for I in 0 .. Samples loop
                  Add_Point (Bird, Mid_XV (I) + DX, Mid_Y (I) + DY);
               end loop;
               for I in reverse 0 .. Samples loop
                  if Bot_X (I) <= Gate then
                     Add_Point (Bird, Bot_X (I) + DX, Bot_Y (I) + DY);
                  end if;
               end loop;
               for I in reverse 0 .. Samples loop
                  Add_Point (Bird, Left_X (I) + DX, Left_Y (I) + DY);
               end loop;

               for I in 0 .. Samples loop
                  Add_Point (Fish, Right_X (I) + DX, Right_Y (I) + DY);
               end loop;
               for I in reverse 0 .. Samples loop
                  if Bot_X (I) >= Gate then
                     Add_Point (Fish, Bot_X (I) + DX, Bot_Y (I) + DY);
                  end if;
               end loop;
               for I in reverse 0 .. Samples loop
                  Add_Point (Fish, Mid_XV (I) + DX, Mid_Y (I) + DY);
               end loop;
            end;
         end loop;
      end loop;
      Built := True;
   end Build_Outlines;

   function Outline_Count (Shape : Shape_Index) return Integer is
   begin
      if not Built then
         Build_Outlines;
      end if;
      return Counts (Shape);
   end Outline_Count;

   function Outline_X (Shape : Shape_Index; Index : Natural) return Integer is
      Slot : constant Integer := Integer (Shape) * Max_Outline * 2 + Index * 2;
   begin
      return XY (Slot);
   end Outline_X;

   function Outline_Y (Shape : Shape_Index; Index : Natural) return Integer is
      Slot : constant Integer := Integer (Shape) * Max_Outline * 2 + Index * 2;
   begin
      return XY (Slot + 1);
   end Outline_Y;

   function Outline_Count_Address return System.Address is (Counts'Address);
   function Outline_XY_Address return System.Address is (XY'Address);

   function Blend return Integer is (Mix);

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

   procedure Refresh is
   begin
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
      Hist (Hist_Len) := (Mix, Taps, Found, Which);
   end Remember;

   procedure Reset is
   begin
      if not Built then
         Build_Outlines;
      end if;
      Mix := 0;
      Taps := 0;
      Found := 0;
      Which := -1;
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
      Err := Ok;
      Refresh;
   end Undo;

   function Exported_Shapes return Integer is (Shape_Count);
   function Meta_Address return System.Address is (Meta'Address);
   function Shape_Layer_Address return System.Address is (Layer_Slot'Address);
   function Shape_Kind_Address return System.Address is (Kind_Slot'Address);
   function Shape_Ink_Address return System.Address is (Ink_Slot'Address);

   procedure Reset_Exported is
   begin
      Reset;
   end Reset_Exported;

   procedure Blend_Exported (Value : Integer) is
   begin
      Set_Blend (Value);
   end Blend_Exported;

   procedure Tap_Exported (Shape : Integer) is
   begin
      Tap (Shape);
   end Tap_Exported;

   procedure Undo_Exported is
   begin
      Undo;
   end Undo_Exported;

end Figure;
