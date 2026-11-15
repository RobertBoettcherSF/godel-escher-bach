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
