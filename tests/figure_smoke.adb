with Ada.Command_Line;
with Ada.Text_IO;
with Figure;
with System;

procedure Figure_Smoke is
   use Ada.Text_IO;
   use type Figure.Status_Kind;
   use type System.Address;

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Put_Line ("FAIL " & Message);
      end if;
   end Check;

   function Near (A, B : Float; Tol : Float := 0.0001) return Boolean is
     (abs (A - B) <= Tol);

   function Far (A, B : Float) return Boolean is (abs (A - B) > 0.02);

   procedure Check_Symmetry (Curve_Id : Natural; Name : String) is
      Last : constant Natural := Figure.Curve_Len (Curve_Id) - 1;
   begin
      for K in 0 .. Last loop
         Check
           (Near (Figure.Curve_X (Curve_Id, K) + Figure.Curve_X (Curve_Id, Last - K), 1.0, 0.00001),
            Name & " x symmetry");
         Check
           (Near (Figure.Curve_Y (Curve_Id, K) + Figure.Curve_Y (Curve_Id, Last - K), 0.0, 0.00001),
            Name & " y symmetry");
         exit when Failures > 8;
      end loop;
   end Check_Symmetry;

   procedure Check_Shared (Message : String; Up, Down : Figure.Shape_Index; U, D : Figure.Point_Index) is
   begin
      Check
        (Near (Figure.Point_X (Up, U), Figure.Point_X (Down, D), 0.00001)
         and then Near (Figure.Point_Y (Up, U), Figure.Point_Y (Down, D), 0.00001),
         Message);
   end Check_Shared;

   Up : Figure.Shape_Index;
   Dn : Figure.Shape_Index;
   Bend : Float;
begin
   Figure.Reset;
   Check (Figure.Exported_Shapes = Figure.Shape_Count, "shapes");
   Check (Figure.Meta_Address /= System.Null_Address, "meta");
   Check (Figure.Kind_Address /= System.Null_Address, "kind");
   Check (Figure.Outline_Address /= System.Null_Address, "outline");
   Check (Figure.Eye_XY_Address /= System.Null_Address, "eyes");
   Check (Figure.Morphing, "opens on the morph");
   Check (Figure.Curve_Len (0) = 157, "curve A length");
   Check (Figure.Curve_Len (1) = 721, "curve S length");
   Check (Near (Figure.Curve_X (0, 0), 0.0) and then Near (Figure.Curve_Y (0, 0), 0.0), "A starts");
   Check (Near (Figure.Curve_X (0, 156), 1.0) and then Near (Figure.Curve_Y (0, 156), 0.0), "A ends");
   Check (Near (Figure.Curve_X (0, 10), 0.20296296, 0.00002), "A sample x");
   Check (Near (Figure.Curve_Y (0, 10), 0.02222222, 0.00002), "A sample y");
   Check_Symmetry (0, "A");
   Check_Symmetry (1, "S");

   Figure.Set_Uniform (100);
   Up := Figure.Shape_Of (1, 2, 0);
   Dn := Figure.Shape_Of (1, 2, 1);
   Check (Figure.Shape_Kind (Up) = 0, "dark kind");
   Check (Figure.Shape_Kind (Dn) = 1, "cream kind");
   for M in 1 .. 719 loop
      Check_Shared
        ("shared EC",
         Up, Dn,
         Figure.Point_Index (156 + M),
         Figure.Point_Index (1596 - M));
      exit when Failures > 0;
   end loop;
   Check_Shared ("shared EB end", Up, Figure.Shape_Of (0, 2, 1), 877, 719);
   Check_Shared ("shared EB start", Up, Figure.Shape_Of (0, 2, 1), 1596, 0);
   Check_Shared ("shared EA end", Up, Figure.Shape_Of (1, 1, 1), 155, 721);
   Check_Shared ("shared EA start", Up, Figure.Shape_Of (1, 1, 1), 0, 876);

   declare
      A : constant Float := Figure.Point_X (Up, 0);
      B : constant Float := Figure.Point_X (Up, 156);
      Mid_X : constant Float := (A + B) / 2.0;
      Mid_Y : constant Float :=
        (Figure.Point_Y (Up, 0) + Figure.Point_Y (Up, 156)) / 2.0;
   begin
      for K in 0 .. 156 loop
         Check
           (Near
              (Figure.Point_X (Up, K)
               + Figure.Point_X (Up, 156 - K),
               Mid_X * 2.0, 0.00005)
            and then
              Near
                (Figure.Point_Y (Up, K)
                 + Figure.Point_Y (Up, 156 - K),
                 Mid_Y * 2.0, 0.00005),
            "edge midpoint symmetry");
         exit when Failures > 0;
      end loop;
   end;

   Figure.Set_Uniform (0);
   Check (Figure.Eye_Count = 0, "no eyes on triangles");
   Bend := 0.0;
   for K in 0 .. 156 loop
      declare
         Cross : constant Float :=
           (Figure.Point_X (Up, K) - Figure.Point_X (Up, 0))
           * (Figure.Point_Y (Up, 156) - Figure.Point_Y (Up, 0))
           - (Figure.Point_Y (Up, K) - Figure.Point_Y (Up, 0))
           * (Figure.Point_X (Up, 156) - Figure.Point_X (Up, 0));
      begin
         if abs (Cross) > Bend then
            Bend := abs (Cross);
         end if;
      end;
   end loop;
   Check (Bend < 0.00001, "triangles are straight");

   Figure.Set_Uniform (100);
   Check (Figure.Eye_Count > 0, "birds have eyes");
   Check (Figure.Eye_Kind (0) = 0 and then Figure.Eye_Kind (1) = 1, "both eyes");
   Bend := 0.0;
   for K in 0 .. 156 loop
      declare
         Cross : constant Float :=
           (Figure.Point_X (Up, K) - Figure.Point_X (Up, 0))
           * (Figure.Point_Y (Up, 156) - Figure.Point_Y (Up, 0))
           - (Figure.Point_Y (Up, K) - Figure.Point_Y (Up, 0))
           * (Figure.Point_X (Up, 156) - Figure.Point_X (Up, 0));
      begin
         if abs (Cross) > Bend then
            Bend := abs (Cross);
         end if;
      end;
   end loop;
   Check (Bend > 0.02, "birds leave the straight edge");

   Figure.Reset;
   Check (Figure.Morphing and then Figure.Highlight = 0, "reset clears");
   Check
     (Far (Figure.Point_Y (Figure.Shape_Of (2, 8, 0), 40),
           Figure.Point_Y (Figure.Shape_Of (2, 8, 0), 0))
      and then
        Near (Figure.Point_Y (Figure.Shape_Of (2, -1, 0), 40),
              Figure.Point_Y (Figure.Shape_Of (2, -1, 0), 0), 0.002),
      "top bends, bottom stays flat");

   Figure.Tap (Integer (Up));
   Check (Figure.Highlight = 1 and then Figure.Last_Status = Figure.Ok, "tap dark");
   Figure.Tap (Integer (Dn));
   Check (Figure.Highlight = 2, "tap cream");
   Figure.Tap (Integer (Dn));
   Check (Figure.Highlight = 0, "tap again clears");
   Figure.Undo;
   Check (Figure.Highlight = 2, "undo restores");
   Figure.Tap (-1);
   Check (Figure.Last_Status = Figure.Bad_Shape, "bad shape");
   Figure.Reset;
   Figure.Undo;
   Check (Figure.Last_Status = Figure.Cannot_Undo, "cannot undo reset");

   if Failures = 0 then
      Put_Line ("figure smoke ok");
   else
      Put_Line ("figure smoke failed:" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Figure_Smoke;
