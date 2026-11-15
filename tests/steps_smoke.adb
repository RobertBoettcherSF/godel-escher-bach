with Ada.Command_Line;
with Ada.Text_IO;
with Steps;
with System;

procedure Steps_Smoke is
   use Ada.Text_IO;
   use type Steps.Status_Kind;
   use type System.Address;

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Put_Line ("FAIL " & Message);
      end if;
   end Check;

   function Den (N : Natural) return Integer is
      Result : Integer := 1;
   begin
      for I in 1 .. N loop
         Result := Result * 2;
      end loop;
      return Result;
   end Den;
begin
   Check (Steps.Exported_Max = Steps.Max_Steps, "max");
   Check (Steps.Exported_Scale = Steps.Scale, "scale");
   Check (Steps.Meta_Address /= System.Null_Address, "meta");
   Check (Steps.Widths_Address /= System.Null_Address, "widths");

   Steps.Reset_Exported;
   for N in 0 .. Steps.Max_Steps loop
      pragma Assert (Steps.Count = N, "count");
      pragma Assert (Steps.Gap_Numerator = 1, "gap num");
      pragma Assert (Steps.Gap_Denominator = Den (N), "gap = 1/2^n");
      if N = 0 then
         pragma Assert (Steps.Sum_Numerator = 0, "sum start");
         pragma Assert (Steps.Sum_Denominator = 1, "sum den start");
      else
         pragma Assert (Steps.Sum_Numerator = Den (N) - 1, "sum num");
         pragma Assert (Steps.Sum_Denominator = Den (N), "sum den");
      end if;
      pragma Assert (Steps.Sum_Numerator < Steps.Sum_Denominator, "sum exceeds 1");
      pragma Assert (Steps.Sum_Units + Steps.Gap_Units = Steps.Scale, "units");
      pragma Assert (Steps.Sum_Units < Steps.Scale, "units exceed the bar");
      declare
         Total : Integer := 0;
      begin
         for Index in 1 .. N loop
            pragma Assert (Steps.Step_Units (Index) = Steps.Scale / Den (Index), "width");
            Total := Total + Steps.Step_Units (Index);
         end loop;
         pragma Assert (Total = Steps.Sum_Units, "widths add up");
         pragma Assert (Steps.Step_Units (N + 1) = 0 or else N = Steps.Max_Steps, "no extra");
      end;
      if N < Steps.Max_Steps then
         Steps.Step_Exported;
         pragma Assert (Steps.Last_Status = Steps.Ok, "step status");
      end if;
   end loop;

   Steps.Step_Exported;
   Check (Steps.Last_Status = Steps.Cannot_Step, "full");
   Check (Steps.Count = Steps.Max_Steps, "stays full");
   Check (Steps.Gap_Denominator = Den (Steps.Max_Steps), "full gap");

   Steps.Undo_Exported;
   Check (Steps.Count = Steps.Max_Steps - 1, "undo");
   Check (Steps.Gap_Denominator = Den (Steps.Max_Steps - 1), "undo gap");
   Check (Steps.Sum_Numerator = Den (Steps.Max_Steps - 1) - 1, "undo sum");

   Steps.Reset_Exported;
   Check (Steps.Count = 0, "reset");
   Check (Steps.Gap_Denominator = 1, "reset gap");
   Steps.Undo_Exported;
   Check (Steps.Last_Status = Steps.Cannot_Undo, "no undo");
   Check (Steps.Count = 0, "undo kept the start");

   if Failures = 0 then
      Put_Line ("OK steps=" & Steps.Max_Steps'Image);
   else
      Put_Line ("FAIL" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Steps_Smoke;
