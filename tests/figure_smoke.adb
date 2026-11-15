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

   if Failures = 0 then
      Put_Line ("OK shapes=" & Figure.Shape_Count'Image);
   else
      Put_Line ("FAIL" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Figure_Smoke;
