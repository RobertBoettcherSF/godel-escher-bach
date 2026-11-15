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

   Start_Ink : array (Figure.Cell_Index) of Integer := (others => 0);
   Owned     : array (Figure.Shape_Index) of Natural := (others => 0);
   Layer_0   : Natural := 0;
   Layer_1   : Natural := 0;
begin
   Check (Figure.Exported_Cols = Figure.Cols, "cols");
   Check (Figure.Exported_Rows = Figure.Rows, "rows");
   Check (Figure.Exported_Shapes = Figure.Shape_Count, "shapes");
   Check (Figure.Meta_Address /= System.Null_Address, "meta");
   Check (Figure.Cell_Shape_Address /= System.Null_Address, "cell shape");
   Check (Figure.Cell_Layer_Address /= System.Null_Address, "cell layer");
   Check (Figure.Cell_Ink_Address /= System.Null_Address, "ink");
   Check (Figure.Shape_Layer_Address /= System.Null_Address, "shape layer");
   Check (Figure.Shape_Kind_Address /= System.Null_Address, "kind");
   Check (Figure.Shape_Head_Address /= System.Null_Address, "head");
   Check (Figure.Shape_Dir_C_Address /= System.Null_Address, "dir c");
   Check (Figure.Shape_Dir_R_Address /= System.Null_Address, "dir r");

   Figure.Reset_Exported;

   for Index in Figure.Cell_Index loop
      declare
         Shape : constant Integer := Figure.Cell_Shape (Index);
         Layer : constant Integer := Figure.Cell_Layer (Index);
      begin
         pragma Assert (Shape in 0 .. Figure.Shape_Count - 1, "shape range");
         pragma Assert (Layer = 0 or else Layer = 1, "layer bit");
         pragma Assert
           (Layer = Figure.Shape_Layer (Figure.Shape_Index (Shape)),
            "cell layer matches its shape");
         Owned (Figure.Shape_Index (Shape)) :=
           Owned (Figure.Shape_Index (Shape)) + 1;
         if Layer = 0 then
            Layer_0 := Layer_0 + 1;
            pragma Assert (Figure.Cell_Ink (Index) = 255, "ink on");
         else
            Layer_1 := Layer_1 + 1;
            pragma Assert (Figure.Cell_Ink (Index) = 0, "ink off");
         end if;
         Start_Ink (Index) := Figure.Cell_Ink (Index);
      end;
   end loop;

   pragma Assert (Layer_0 + Layer_1 = Figure.Cell_Count, "partition");
   pragma Assert (Layer_0 > 0 and then Layer_1 > 0, "both layers");
   for Shape in Figure.Shape_Index loop
      pragma Assert (Owned (Shape) > 0, "shape has cells");
      pragma Assert
        (Figure.Cell_Shape (Figure.Shape_Head (Shape)) = Shape,
         "head sits in its shape");
      pragma Assert
        (Figure.Shape_Layer (Shape) = Figure.Shape_Kind (Shape),
         "kind is the layer");
   end loop;

   pragma Assert (Figure.Front_Layer = 0, "birds in front");
   pragma Assert
     (Figure.Shape_Layer (Figure.Shape_Index (Figure.Hidden_Shape)) = 1,
      "hidden one is in the gaps");

   Figure.Tap_Exported (Figure.Hidden_Shape);
   Check (Figure.Last_Found = 1, "found the gap shape");
   Check (Figure.Tap_Count = 1, "one tap");
   Check (Figure.Front_Layer = 1, "swapped");
   Check (Figure.Blend = 100, "full swap");

   Figure.Tap_Exported (0);
   Check (Figure.Blend = 0, "second swap");
   Check (Figure.Front_Layer = 0, "front restored");
   for Index in Figure.Cell_Index loop
      pragma Assert (Figure.Cell_Ink (Index) = Start_Ink (Index), "inks restored");
   end loop;

   Figure.Set_Blend (25);
   pragma Assert ((255 * 25) / 100 = 63, "formula");
   pragma Assert
     (Figure.Cell_Ink (Figure.Shape_Head (0)) = 255 - 63, "bird fade");
   pragma Assert
     (Figure.Cell_Ink (Figure.Shape_Head (1)) = 63, "fish fade");

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
      Put_Line ("OK cells=" & Figure.Cell_Count'Image);
   else
      Put_Line ("FAIL" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Figure_Smoke;
