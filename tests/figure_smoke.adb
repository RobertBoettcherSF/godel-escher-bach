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

   Start_Ink : array (Figure.Shape_Index) of Integer := (others => 0);
   Layer_0   : Natural := 0;
   Layer_1   : Natural := 0;
begin
   Check (Figure.Exported_Shapes = Figure.Shape_Count, "shapes");
   Check (Figure.Meta_Address /= System.Null_Address, "meta");
   Check (Figure.Shape_Layer_Address /= System.Null_Address, "layer");
   Check (Figure.Shape_Kind_Address /= System.Null_Address, "kind");
   Check (Figure.Shape_Ink_Address /= System.Null_Address, "ink");

   Figure.Reset_Exported;

   for Shape in Figure.Shape_Index loop
      declare
         Layer : constant Integer := Figure.Shape_Layer (Shape);
      begin
         pragma Assert (Layer = 0 or else Layer = 1, "one layer bit");
         pragma Assert (Figure.Shape_Kind (Shape) = Layer, "kind is the layer");
         pragma Assert
           (Figure.Shape_Ink (Shape) = (if Layer = 0 then 255 else 0),
            "ink matches the layer");
         if Layer = 0 then
            Layer_0 := Layer_0 + 1;
         else
            Layer_1 := Layer_1 + 1;
         end if;
         Start_Ink (Shape) := Figure.Shape_Ink (Shape);
      end;
   end loop;

   pragma Assert (Layer_0 + Layer_1 = Figure.Shape_Count, "partition");
   pragma Assert (Layer_0 > 0 and then Layer_1 > 0, "both layers");
   pragma Assert (Figure.Front_Layer = 0, "birds in front");
   pragma Assert
     (Figure.Shape_Layer (Figure.Shape_Index (Figure.Hidden_Shape)) = 1,
      "hidden one is in the gaps");

   declare
      Hidden : constant Integer := Figure.Hidden_Shape;
   begin
      Figure.Tap_Exported (Hidden);
      Check (Figure.Last_Found = 1, "found the gap shape");
      Check (Figure.Last_Shape = Hidden, "tapped shape");
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
   pragma Assert (Figure.Shape_Ink (0) = 255 - 63, "bird fade");
   pragma Assert (Figure.Shape_Ink (1) = 63, "fish fade");

   Figure.Undo_Exported;
   Figure.Undo_Exported;
   Check (Figure.Blend = 0, "undo blend");
   Check (Figure.Tap_Count = 0, "undo taps");
   Figure.Undo_Exported;
   Check (Figure.Last_Status = Figure.Cannot_Undo, "no undo");

   Figure.Tap_Exported (99);
   Check (Figure.Last_Status = Figure.Bad_Shape, "bad shape");
   Check (Figure.Blend = 0, "bad shape keeps the picture");

   declare
      function Inside (Shape : Figure.Shape_Index; X, Y : Integer) return Boolean is
         Hits : Natural := 0;
         N    : constant Natural := Figure.Outline_Count (Shape);
      begin
         for I in 0 .. N - 1 loop
            declare
               J  : constant Natural := (if I = N - 1 then 0 else I + 1);
               X1 : constant Integer := Figure.Outline_X (Shape, I);
               Y1 : constant Integer := Figure.Outline_Y (Shape, I);
               X2 : constant Integer := Figure.Outline_X (Shape, J);
               Y2 : constant Integer := Figure.Outline_Y (Shape, J);
            begin
               if (Y1 > Y) /= (Y2 > Y) and then Y2 /= Y1 then
                  if X < X1 + (X2 - X1) * (Y - Y1) / (Y2 - Y1) then
                     Hits := Hits + 1;
                  end if;
               end if;
            end;
         end loop;
         return Hits mod 2 = 1;
      end Inside;

      Missed  : Natural := 0;
      Overlap : Natural := 0;
      Covered : Natural := 0;
      Total   : Natural := 0;
   begin
      Check (Figure.Outline_Count (0) > 20, "bird outline");
      Check (Figure.Outline_Count (1) > 20, "fish outline");

      --  The right edge of the first fish is the left edge of the next bird.
      for I in 0 .. Figure.Outline_Count (1) - 1 loop
         declare
            X : constant Integer := Figure.Outline_X (1, I);
            Y : constant Integer := Figure.Outline_Y (1, I);
            Found : Boolean := False;
         begin
            if X > 720 then
               for J in 0 .. Figure.Outline_Count (2) - 1 loop
                  if abs (Figure.Outline_X (2, J) - X) <= 2
                    and then abs (Figure.Outline_Y (2, J) - Y) <= 2
                  then
                     Found := True;
                     exit;
                  end if;
               end loop;
               Check (Found, "right edge repeated on the next bird");
            end if;
         end;
      end loop;

      for Y in 80 .. 840 loop
         if Y mod 14 = 0 then
            for X in 80 .. 1360 loop
               if X mod 14 = 0 then
                  declare
                     Hits : Natural := 0;
                  begin
                     Total := Total + 1;
                     for Shape in Figure.Shape_Index loop
                        if Inside (Shape, X, Y) then
                           Hits := Hits + 1;
                        end if;
                     end loop;
                     if Hits = 0 then
                        Missed := Missed + 1;
                     elsif Hits = 1 then
                        Covered := Covered + 1;
                     else
                        Overlap := Overlap + 1;
                     end if;
                  end;
               end if;
            end loop;
         end if;
      end loop;
      Check (Missed * 100 < Total * 3, "frame has gaps");
      Check (Overlap * 100 < Total * 3, "tiles overlap");
      Check (Covered * 100 > Total * 90, "tiles cover the frame");
   end;

   if Failures = 0 then
      Put_Line ("OK shapes=" & Figure.Shape_Count'Image);
   else
      Put_Line ("FAIL" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Figure_Smoke;
