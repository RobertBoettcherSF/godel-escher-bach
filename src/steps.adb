package body Steps is

   Taken : Count_Range := 0;
   Err   : Status_Kind := Ok;

   Meta   : array (1 .. 10) of Integer := (others => 0);
   Widths : array (1 .. Max_Steps) of Integer := (others => 0);

   function Power (N : Count_Range) return Integer is
      Result : Integer := 1;
   begin
      for I in 1 .. N loop
         Result := Result * 2;
      end loop;
      return Result;
   end Power;

   function Count return Count_Range is (Taken);

   function Last_Status return Status_Kind is (Err);

   function Gap_Numerator return Integer is (1);

   function Gap_Denominator return Integer is
     (if Taken = 0 then 1 else Power (Taken));

   function Sum_Numerator return Integer is
     (if Taken = 0 then 0 else Gap_Denominator - 1);

   function Sum_Denominator return Integer is (Gap_Denominator);

   function Gap_Units return Integer is (Scale / Gap_Denominator);

   function Sum_Units return Integer is (Scale - Gap_Units);

   function Step_Units (Index : Positive) return Integer is
   begin
      if Index > Taken then
         return 0;
      end if;
      return Scale / Power (Count_Range (Index));
   end Step_Units;

   function Status_Code (Status : Status_Kind) return Integer is
   begin
      case Status is
         when Ok =>
            return 0;
         when Cannot_Step =>
            return 2;
         when Cannot_Undo =>
            return 5;
      end case;
   end Status_Code;

   procedure Refresh is
   begin
      Meta (1) := Taken;
      Meta (2) := Status_Code (Err);
      Meta (3) := Gap_Numerator;
      Meta (4) := Gap_Denominator;
      Meta (5) := Sum_Numerator;
      Meta (6) := Sum_Denominator;
      Meta (7) := Gap_Units;
      Meta (8) := Sum_Units;
      Meta (9) := Scale;
      Meta (10) := Max_Steps;
      for Index in Widths'Range loop
         Widths (Index) := Step_Units (Index);
      end loop;
   end Refresh;

   procedure Reset is
   begin
      Taken := 0;
      Err := Ok;
      Refresh;
   end Reset;

   procedure Step is
   begin
      if Taken = Max_Steps then
         Err := Cannot_Step;
         Refresh;
         return;
      end if;
      Taken := Taken + 1;
      Err := Ok;
      Refresh;
   end Step;

   procedure Undo is
   begin
      if Taken = 0 then
         Err := Cannot_Undo;
         Refresh;
         return;
      end if;
      Taken := Taken - 1;
      Err := Ok;
      Refresh;
   end Undo;

   function Exported_Max return Integer is (Max_Steps);
   function Exported_Scale return Integer is (Scale);
   function Meta_Address return System.Address is (Meta'Address);
   function Widths_Address return System.Address is (Widths'Address);

   procedure Reset_Exported is
   begin
      Reset;
   end Reset_Exported;

   procedure Step_Exported is
   begin
      Step;
   end Step_Exported;

   procedure Undo_Exported is
   begin
      Undo;
   end Undo_Exported;

end Steps;
