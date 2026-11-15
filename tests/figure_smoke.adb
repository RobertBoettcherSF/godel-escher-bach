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

   function Inside
     (Shape : Figure.Shape_Index; X, Y : Float) return Boolean
   is
      Hit : Boolean := False;
      J   : Natural := Figure.Point_Count (Shape) - 1;
   begin
      for I in 0 .. Figure.Point_Count (Shape) - 1 loop
         declare
            Xi : constant Float := Figure.Point_X (Shape, I);
            Yi : constant Float := Figure.Point_Y (Shape, I);
            Xj : constant Float := Figure.Point_X (Shape, J);
            Yj : constant Float := Figure.Point_Y (Shape, J);
         begin
            if ((Yi > Y) /= (Yj > Y))
              and then X < (Xj - Xi) * (Y - Yi) / (Yj - Yi) + Xi
            then
               Hit := not Hit;
            end if;
         end;
         J := I;
      end loop;
      return Hit;
   end Inside;

   procedure Check_Cover (Grow_Value : Integer) is
      Zero : Natural := 0;
      Many : Natural := 0;
      X    : Float := 216.2;
   begin
      Figure.Set_Grow (Grow_Value);
      while X < 760.0 loop
         declare
            Y : Float := 130.5;
         begin
            while Y < 520.0 loop
               declare
                  Hits : Natural := 0;
               begin
                  for Shape in Figure.Shape_Index loop
                     if Inside (Shape, X, Y) then
                        Hits := Hits + 1;
                        exit when Hits > 1;
                     end if;
                  end loop;
                  if Hits = 0 then
                     Zero := Zero + 1;
                  elsif Hits > 1 then
                     Many := Many + 1;
                  end if;
               end;
               Y := Y + 13.0;
            end loop;
         end;
         X := X + 13.0;
      end loop;
      Check (Zero = 0, "gap at grow" & Grow_Value'Image);
      Check (Many = 0, "overlap at grow" & Grow_Value'Image);
   end Check_Cover;

   Start_Ink : array (Figure.Shape_Index) of Integer := (others => 0);
   Layer_0   : Natural := 0;
   Layer_1   : Natural := 0;
begin
   Check (Figure.Exported_Shapes = Figure.Shape_Count, "shapes");
   Check (Figure.Meta_Address /= System.Null_Address, "meta");
   Check (Figure.Shape_Layer_Address /= System.Null_Address, "layer");
   Check (Figure.Shape_Kind_Address /= System.Null_Address, "kind");
   Check (Figure.Shape_Ink_Address /= System.Null_Address, "ink");
   Check (Figure.Outline_Count_Address /= System.Null_Address, "counts");
   Check (Figure.Outline_XY_Address /= System.Null_Address, "xy");
   Check (Figure.Outline_Stride = 3 * Figure.Samples * 2, "stride");

   Figure.Reset_Exported;
   Check (Figure.Grow = 100, "birds at the start");

   for Shape in Figure.Shape_Index loop
      declare
         Layer : constant Integer := Figure.Shape_Layer (Shape);
      begin
         pragma Assert (Layer = 0 or else Layer = 1, "one layer bit");
         pragma Assert (Figure.Shape_Kind (Shape) = Layer, "kind is the layer");
         pragma Assert
           (Figure.Shape_Ink (Shape) = (if Layer = 0 then 255 else 0),
            "ink matches the layer");
         pragma Assert
           (Figure.Point_Count (Shape) = 3 * Figure.Samples, "outline length");
         if Layer = 0 then
            Layer_0 := Layer_0 + 1;
         else
            Layer_1 := Layer_1 + 1;
         end if;
         Start_Ink (Shape) := Figure.Shape_Ink (Shape);
      end;
   end loop;

   pragma Assert (Layer_0 + Layer_1 = Figure.Shape_Count, "partition");
   pragma Assert (Layer_0 = Layer_1, "equal birds");
   pragma Assert (Figure.Front_Layer = 0, "dark birds in front");
   pragma Assert
     (Figure.Shape_Layer (Figure.Shape_Index (Figure.Hidden_Shape)) = 1,
      "hidden one is a light bird");

   declare
      X0 : constant Float := Figure.Point_X (0, 0);
      Y0 : constant Float := Figure.Point_Y (0, 0);
      X1 : constant Float := Figure.Point_X (0, Figure.Samples);
      Y1 : constant Float := Figure.Point_Y (0, Figure.Samples);
      Xm : constant Float := Figure.Point_X (0, Figure.Samples / 3);
      Ym : constant Float := Figure.Point_Y (0, Figure.Samples / 3);
      Dx : constant Float := X1 - X0;
      Dy : constant Float := Y1 - Y0;
      Cross : constant Float := (Xm - X0) * Dy - (Ym - Y0) * Dx;
      Len2  : constant Float := Dx * Dx + Dy * Dy;
   begin
      Check (X1 > X0 + 100.0, "dark bird flies right");
      Check (Figure.Point_X (1, Figure.Samples) < Figure.Point_X (1, 0) - 100.0,
             "light bird flies left");
      Check (Cross * Cross > 100.0 * Len2, "back is bent");
      Figure.Set_Grow (0);
      declare
         Ax : constant Float := Figure.Point_X (0, 0);
         Ay : constant Float := Figure.Point_Y (0, 0);
         Bx : constant Float := Figure.Point_X (0, Figure.Samples);
         By : constant Float := Figure.Point_Y (0, Figure.Samples);
         Mx : constant Float := Figure.Point_X (0, Figure.Samples / 2);
         My : constant Float := Figure.Point_Y (0, Figure.Samples / 2);
         Ex : constant Float := Bx - Ax;
         Ey : constant Float := By - Ay;
         Gap : constant Float := (Mx - Ax) * Ey - (My - Ay) * Ex;
         Base : constant Float := Ex * Ex + Ey * Ey;
      begin
         Check (Gap * Gap < 0.0001 * Base, "grow 0 is a straight edge");
      end;
      Figure.Set_Grow (100);
   end;

   for Shape in Figure.Shape_Index loop
      if Figure.Shape_Layer (Shape) = 0 then
         declare
            Left  : constant Figure.Shape_Index := Figure.Shape_Index (Shape + 1);
            Axis  : constant Float :=
              Figure.Point_X (Shape, 2 * Figure.Samples + Figure.Samples / 2);
         begin
            pragma Assert (Figure.Shape_Layer (Left) = 1, "pair");
            for Index in 0 .. Figure.Point_Count (Shape) - 1 loop
               pragma Assert
                 (abs (Figure.Point_X (Left, Index)
                    - (2.0 * Axis - Figure.Point_X (Shape, Index))) < 0.02,
                  "mirror x");
               pragma Assert
                 (abs (Figure.Point_Y (Left, Index) - Figure.Point_Y (Shape, Index))
                    < 0.02,
                  "mirror y");
            end loop;
         end;
      end if;
   end loop;

   Check_Cover (0);
   Check_Cover (100);

   declare
      Hidden : constant Integer := Figure.Hidden_Shape;
   begin
      Figure.Set_Grow (30);
      Figure.Tap_Exported (Hidden);
      Check (Figure.Last_Found = 1, "found the gap shape");
      Check (Figure.Last_Shape = Hidden, "tapped shape");
      Check (Figure.Grow = 30, "tap keeps the grow");
   end;
   Check (Figure.Tap_Count = 1, "one tap");
   Check (Figure.Front_Layer = 1, "swapped");
   Check (Figure.Blend = 100, "full swap");

   Figure.Tap_Exported (0);
   Check (Figure.Blend = 0, "second swap");
   Check (Figure.Front_Layer = 0, "front restored");
   for Shape in Figure.Shape_Index loop
      pragma Assert (Figure.Shape_Ink (Shape) = Start_Ink (Shape), "inks restored");
   end loop;

   Figure.Set_Blend (25);
   pragma Assert ((255 * 25) / 100 = 63, "formula");
   pragma Assert (Figure.Shape_Ink (0) = 255 - 63, "dark fade");
   pragma Assert (Figure.Shape_Ink (1) = 63, "light fade");

   Figure.Undo_Exported;
   Figure.Undo_Exported;
   Check (Figure.Blend = 0, "undo blend");
   Check (Figure.Tap_Count = 0, "undo taps");
   Check (Figure.Grow = 100, "undo grow");
   Figure.Undo_Exported;
   Check (Figure.Last_Status = Figure.Cannot_Undo, "no undo");

   Figure.Tap_Exported (999);
   Check (Figure.Last_Status = Figure.Bad_Shape, "bad shape");
   Check (Figure.Blend = 0, "bad shape keeps the picture");

   Figure.Set_Grow (-4);
   Check (Figure.Grow = 0, "grow floor");
   Figure.Set_Grow (140);
   Check (Figure.Grow = 100, "grow ceiling");

   if Failures = 0 then
      Put_Line ("OK shapes=" & Figure.Shape_Count'Image);
   else
      Put_Line ("FAIL" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Figure_Smoke;
