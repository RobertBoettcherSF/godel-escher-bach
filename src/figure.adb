package body Figure is

   type Center is record
      Col   : Natural;
      Row   : Natural;
      Layer : Integer;
      Kind  : Integer;
      Dir_C : Integer;
      Dir_R : Integer;
   end record;

   --  Birds (layer 0) and fish (layer 1) sit on two staggered rows so the
   --  regions between them interlock instead of making stripes.
   Centers : constant array (Shape_Index) of Center :=
     ((5, 4, 0, 0, 1, 0),
      (12, 6, 1, 1, -1, 0),
      (19, 4, 0, 0, 1, 0),
      (5, 12, 1, 1, -1, 0),
      (12, 10, 0, 0, 1, 0),
      (19, 12, 1, 1, -1, 0));

   type Snap is record
      Mix   : Integer := 0;
      Taps  : Integer := 0;
      Found : Integer := 0;
   end record;

   Max_Hist : constant := 24;

   Mix      : Integer     := 0;
   Taps     : Integer     := 0;
   Found    : Integer     := 0;
   Err      : Status_Kind := Ok;
   Hist     : array (1 .. Max_Hist) of Snap := (others => (0, 0, 0));
   Hist_Len : Natural     := 0;

   Cell_Shapes : array (Cell_Index) of Integer := (others => 0);
   Cell_Layers : array (Cell_Index) of Integer := (others => 0);
   Cell_Inks   : array (Cell_Index) of Integer := (others => 0);

   Meta        : array (1 .. 8) of Integer := (others => 0);
   Kind_Slot   : array (Shape_Index) of Integer := (others => 0);
   Layer_Slot  : array (Shape_Index) of Integer := (others => 0);
   Head_Slot   : array (Shape_Index) of Integer := (others => 0);
   Dir_C_Slot  : array (Shape_Index) of Integer := (others => 0);
   Dir_R_Slot  : array (Shape_Index) of Integer := (others => 0);

   function Blend return Integer is (Mix);

   function Front_Layer return Integer is
     (if Mix < 50 then 0 else 1);

   function Tap_Count return Integer is (Taps);

   function Last_Found return Integer is (Found);

   function Last_Status return Status_Kind is (Err);

   function Shape_Layer (Shape : Shape_Index) return Integer is
     (Centers (Shape).Layer);

   function Shape_Kind (Shape : Shape_Index) return Integer is
     (Centers (Shape).Kind);

   function Shape_Head (Shape : Shape_Index) return Integer is
     (Centers (Shape).Row * Cols + Centers (Shape).Col);

   function Shape_Dir_C (Shape : Shape_Index) return Integer is
     (Centers (Shape).Dir_C);

   function Shape_Dir_R (Shape : Shape_Index) return Integer is
     (Centers (Shape).Dir_R);

   function Hidden_Shape return Integer is
   begin
      for Shape in Shape_Index loop
         if Shape_Layer (Shape) /= Front_Layer then
            return Shape;
         end if;
      end loop;
      return 0;
   end Hidden_Shape;

   function Nearest (Col, Row : Natural) return Shape_Index is
      Best   : Shape_Index := 0;
      Best_D : Integer     := Integer'Last;
      D      : Integer;
      DC     : Integer;
      DR     : Integer;
   begin
      for Shape in Shape_Index loop
         DC := Col - Centers (Shape).Col;
         DR := Row - Centers (Shape).Row;
         D := DC * DC + DR * DR;
         if D < Best_D then
            Best_D := D;
            Best := Shape;
         end if;
      end loop;
      return Best;
   end Nearest;

   function Ink_Of (Layer : Integer) return Integer is
   begin
      if Layer = 0 then
         return 255 - (255 * Mix) / 100;
      end if;
      return (255 * Mix) / 100;
   end Ink_Of;

   procedure Classify is
      Index : Cell_Index;
      Shape : Shape_Index;
   begin
      for Row in 0 .. Rows - 1 loop
         for Col in 0 .. Cols - 1 loop
            Index := Row * Cols + Col;
            Shape := Nearest (Col, Row);
            Cell_Shapes (Index) := Shape;
            Cell_Layers (Index) := Shape_Layer (Shape);
            Cell_Inks (Index) := Ink_Of (Cell_Layers (Index));
         end loop;
      end loop;
      for Shape in Shape_Index loop
         Layer_Slot (Shape) := Shape_Layer (Shape);
         Kind_Slot (Shape) := Shape_Kind (Shape);
         Head_Slot (Shape) := Shape_Head (Shape);
         Dir_C_Slot (Shape) := Shape_Dir_C (Shape);
         Dir_R_Slot (Shape) := Shape_Dir_R (Shape);
      end loop;
   end Classify;

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
      for Index in Cell_Index loop
         Cell_Inks (Index) := Ink_Of (Cell_Layers (Index));
      end loop;
      Meta (1) := Mix;
      Meta (2) := Front_Layer;
      Meta (3) := Taps;
      Meta (4) := Hidden_Shape;
      Meta (5) := Found;
      Meta (6) := Status_Code (Err);
      Meta (7) := Shape_Count;
      Meta (8) := Cell_Count;
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
      Hist (Hist_Len) := (Mix, Taps, Found);
   end Remember;

   procedure Reset is
   begin
      Mix := 0;
      Taps := 0;
      Found := 0;
      Err := Ok;
      Hist_Len := 0;
      Classify;
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
      Err := Ok;
      Refresh;
   end Undo;

   function Cell_Shape (Index : Cell_Index) return Integer is
     (Cell_Shapes (Index));

   function Cell_Layer (Index : Cell_Index) return Integer is
     (Cell_Layers (Index));

   function Cell_Ink (Index : Cell_Index) return Integer is
     (Cell_Inks (Index));

   function Exported_Cols return Integer is (Cols);
   function Exported_Rows return Integer is (Rows);
   function Exported_Shapes return Integer is (Shape_Count);
   function Meta_Address return System.Address is (Meta'Address);
   function Cell_Shape_Address return System.Address is (Cell_Shapes'Address);
   function Cell_Layer_Address return System.Address is (Cell_Layers'Address);
   function Cell_Ink_Address return System.Address is (Cell_Inks'Address);
   function Shape_Layer_Address return System.Address is (Layer_Slot'Address);
   function Shape_Kind_Address return System.Address is (Kind_Slot'Address);
   function Shape_Head_Address return System.Address is (Head_Slot'Address);
   function Shape_Dir_C_Address return System.Address is (Dir_C_Slot'Address);
   function Shape_Dir_R_Address return System.Address is (Dir_R_Slot'Address);

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
