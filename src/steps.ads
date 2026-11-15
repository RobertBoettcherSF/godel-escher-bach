--  Halving steps. Each step closes half the remaining gap, so after n steps
--  the gap is 1/2^n and the steps add up to (2^n - 1)/2^n, always below 1.
--  The fractions are exact integers. 2^30 fits in a 32-bit signed integer,
--  which is the WebAssembly ABI, so the page stops at 30 steps.

with System;

package Steps is

   Max_Steps : constant := 30;
   Scale     : constant := 2 ** 30;

   subtype Count_Range is Natural range 0 .. Max_Steps;

   type Status_Kind is (Ok, Cannot_Step, Cannot_Undo);

   procedure Reset;
   procedure Step;
   procedure Undo;

   function Count return Count_Range;
   function Last_Status return Status_Kind;
   function Gap_Numerator return Integer;
   function Gap_Denominator return Integer;
   function Sum_Numerator return Integer;
   function Sum_Denominator return Integer;
   function Step_Units (Index : Positive) return Integer;
   function Gap_Units return Integer;
   function Sum_Units return Integer;

   function Exported_Max return Integer
     with Export, Convention => C, External_Name => "steps_max";
   function Exported_Scale return Integer
     with Export, Convention => C, External_Name => "steps_scale";
   function Meta_Address return System.Address
     with Export, Convention => C, External_Name => "steps_meta";
   function Widths_Address return System.Address
     with Export, Convention => C, External_Name => "steps_widths";

   procedure Reset_Exported
     with Export, Convention => C, External_Name => "steps_reset";
   procedure Step_Exported
     with Export, Convention => C, External_Name => "steps_step";
   procedure Undo_Exported
     with Export, Convention => C, External_Name => "steps_undo";

end Steps;
