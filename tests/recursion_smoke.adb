with Ada.Command_Line;
with Ada.Text_IO;
with Recursion;

procedure Recursion_Smoke is
   use Ada.Text_IO;
   use type Recursion.Status_Kind;

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Put_Line ("FAIL " & Message);
      end if;
   end Check;

   function Expected_Segments (Depth : Natural) return Natural is
      (2 ** (Depth + 1) - 1);

   procedure Check_Tree (Depth : Natural) is
      Min_X, Max_X, Mid : Integer;
   begin
      Recursion.Set_Tree (Depth);
      Check (Recursion.Segment_Count = Expected_Segments (Depth), "segment count");
      Check (Recursion.Last_Status = Recursion.Ok, "tree ok");
      Min_X := Recursion.Segment_X1 (0);
      Max_X := Min_X;
      for I in 0 .. Recursion.Segment_Count - 1 loop
         Min_X := Integer'Min (Min_X, Integer'Min (Recursion.Segment_X1 (I), Recursion.Segment_X2 (I)));
         Max_X := Integer'Max (Max_X, Integer'Max (Recursion.Segment_X1 (I), Recursion.Segment_X2 (I)));
         Check (Recursion.Segment_Level (I) in 0 .. Depth, "level");
         Check (Recursion.Segment_X1 (I) in 40 .. 960, "inside the frame");
         Check (Recursion.Segment_Y1 (I) in 40 .. 960, "inside the frame");
         exit when Failures > 4;
      end loop;
      Mid := (Min_X + Max_X) / 2;
      Check (abs (Mid - 500) <= 2, "tree is centred");
      Check
        (abs (Recursion.Segment_X1 (0) - Recursion.Segment_X2 (0)) <= 2,
         "trunk is upright");
   end Check_Tree;

   Reds, Blues : Natural;
begin
   Recursion.Reset;
   Check (Recursion.Frame_Depth = 1, "starts on the outer frame");
   Check (Recursion.Tree_Depth = 5, "tree opens midway");
   Check (Recursion.Rabbit_Terms = 1 and then Recursion.Rabbit_Value = 1, "opens on one rabbit");
   for Step in 1 .. 5 loop
      Recursion.Deeper;
   end loop;
   Check (Recursion.Frame_Depth = 6, "six frames");
   Recursion.Deeper;
   Check (Recursion.Last_Status = Recursion.At_Top, "no seventh frame");
   Check (Recursion.Frame_Depth = 6, "depth stays");
   for Step in 1 .. 5 loop
      Recursion.Back;
   end loop;
   Check (Recursion.Frame_Depth = 1, "back to the outside");
   Recursion.Back;
   Check (Recursion.Last_Status = Recursion.At_Bottom, "cannot leave the outside");

   Check_Tree (0);
   Check (Recursion.Segment_Count = 1, "a trunk");
   Check_Tree (1);
   Check_Tree (5);
   Check_Tree (10);
   declare
      First_X : constant Integer := Recursion.Segment_X2 (3);
   begin
      Recursion.Set_Tree (10);
      Check (Recursion.Segment_X2 (3) = First_X, "the tree repeats");
   end;

   Recursion.Reset_Rabbits;
   Check (Recursion.Rabbit_Terms = 1 and then Recursion.Rabbit_Value = 1, "starts at one");
   Check (Recursion.Dot_Count = 1, "one dot");
   Recursion.Next_Rabbit;
   Check (Recursion.Rabbit_Value = 1 and then Recursion.Rabbit_Terms = 2, "second one");
   Recursion.Next_Rabbit;
   Check (Recursion.Rabbit_Value = 2, "two rabbits");
   Check (Recursion.Rabbit_Older = 1 and then Recursion.Rabbit_Newer = 1, "two parents");
   for Step in 1 .. 8 loop
      Recursion.Next_Rabbit;
   end loop;
   Check (Recursion.Rabbit_Value = 89, "eighty-nine");
   Check (Recursion.Rabbit_Older = 34 and then Recursion.Rabbit_Newer = 55, "parents of 89");
   Reds := 0;
   Blues := 0;
   for I in 0 .. Recursion.Dot_Count - 1 loop
      if Recursion.Dot_Pile (I) = 2 then
         if Recursion.Dot_Color (I) = 0 then
            Reds := Reds + 1;
         else
            Blues := Blues + 1;
         end if;
         Check (Recursion.Dot_R (I) >= 10, "new pile stays big");
      end if;
      exit when Failures > 8;
   end loop;
   Check (Reds = 34 and then Blues = 55, "the new pile is the two piles before");
   Recursion.Next_Rabbit;
   Check (Recursion.Last_Status = Recursion.Full, "cap");
   Check (Recursion.Rabbit_Value = 89, "cap holds");
   Recursion.Reset_Rabbits;
   Check (Recursion.Rabbit_Terms = 1 and then Recursion.Dot_Count = 1, "reset rabbits");

   if Failures = 0 then
      Put_Line ("recursion smoke ok");
   else
      Put_Line ("recursion smoke failed:" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Recursion_Smoke;
