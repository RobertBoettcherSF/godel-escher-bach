with Ada.Command_Line;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Hash;
with Ada.Text_IO;
with MIU;
with System;

procedure Smoke is
   use Ada.Text_IO;
   use type Ada.Containers.Count_Type;
   use type MIU.Status_Kind;
   use type System.Address;

   function Same (Left, Right : String) return Boolean is (Left = Right);

   package Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                 => Ada.Strings.Hash,
      Equivalent_Elements => Same);

   package Queues is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Put_Line ("FAIL " & Message);
      end if;
   end Check;

   procedure Load
     (Item   : String;
      Result : out MIU.Buffer;
      Length : out MIU.Length_Range)
   is
   begin
      Result := (others => Character'Val (0));
      if Item'Length > MIU.Max_Length then
         Length := 0;
         return;
      end if;
      Length := Item'Length;
      for Index in 1 .. Item'Length loop
         Result (Index) := Item (Item'First + Index - 1);
      end loop;
   end Load;

   function Image (Item : MIU.Buffer; Length : MIU.Length_Range) return String is
      Text : String (1 .. Length);
   begin
      for Index in Text'Range loop
         Text (Index) := Item (Index);
      end loop;
      return Text;
   end Image;

   function Count_I (Item : MIU.Buffer; Length : MIU.Length_Range) return Natural is
      Total : Natural := 0;
   begin
      for Index in 1 .. Length loop
         if Item (Index) = 'I' then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end Count_I;

   function Current return String is
      Text : String (1 .. MIU.Current_Length);
   begin
      for Index in Text'Range loop
         Text (Index) := MIU.Current_Symbol (Index);
      end loop;
      return Text;
   end Current;

   procedure Expect (Rule : MIU.Rule_Kind; Position : Natural; Item : String; Want : String) is
      Source, Result : MIU.Buffer;
      Source_Length, Result_Length : MIU.Length_Range;
      Status : MIU.Status_Kind;
   begin
      Load (Item, Source, Source_Length);
      MIU.Transform (Source, Source_Length, Rule, Position, Result, Result_Length, Status);
      Check (Status = MIU.Ok, "status " & Item);
      Check (Image (Result, Result_Length) = Want, "want " & Want & " from " & Item);
   end Expect;

   procedure Expect_Bad
     (Rule : MIU.Rule_Kind;
      Position : Natural;
      Item : String;
      Want : MIU.Status_Kind)
   is
      Source, Result : MIU.Buffer;
      Source_Length, Result_Length : MIU.Length_Range;
      Status : MIU.Status_Kind;
   begin
      Load (Item, Source, Source_Length);
      MIU.Transform (Source, Source_Length, Rule, Position, Result, Result_Length, Status);
      Check (Status = Want, "bad status " & Item);
      Check (Result_Length = 0, "bad length " & Item);
   end Expect_Bad;

   function MIU_Buffer (Item : String) return MIU.Buffer is
      Result : MIU.Buffer;
      Length : MIU.Length_Range;
   begin
      Load (Item, Result, Length);
      return Result;
   end MIU_Buffer;

   procedure Check_Session (Want : String) is
   begin
      Check (Current = Want, "session " & Want & " got " & Current);
      Check
        (MIU.I_Count = Count_I (MIU_Buffer (Want), Want'Length),
         "i-count " & Want);
      Check (MIU.Last_Status = MIU.Ok, "session status " & Want);
      Check (MIU.Meta_At (1) = Integer (MIU.Current_Length), "meta length");
      Check (MIU.Meta_At (2) = Integer (MIU.I_Count), "meta i");
      Check (MIU.Meta_At (3) = Integer (MIU.History_Count), "meta history");
      Check (MIU.Meta_At (4) = 0, "meta error");
      Check (MIU.History_Step_Length (MIU.History_Count) = Want'Length, "hist len");
      for Index in 1 .. Want'Length loop
         Check (MIU.History_Symbol (MIU.History_Count, Index) = Want (Index), "hist char");
      end loop;
   end Check_Session;

   procedure Search is
      Seen  : Sets.Set;
      Queue : Queues.Vector;
      Head  : Positive := 1;

      procedure Consider (Item : MIU.Buffer; Length : MIU.Length_Range) is
         Text : constant String := Image (Item, Length);
         Marks : constant Natural := Count_I (Item, Length);
      begin
         pragma Assert (Length > 0, "empty string");
         pragma Assert (Marks mod 3 /= 0, "I-count divisible by 3: " & Text);
         pragma Assert (Text /= "MU", "MU appeared");
         pragma Assert (Text (Text'First) = 'M', "left the initial M: " & Text);
         for Symbol of Text loop
            pragma Assert
              (Symbol = 'M' or else Symbol = 'I' or else Symbol = 'U',
               "unexpected block");
         end loop;
         if Length <= 12 and then not Seen.Contains (Text) then
            Seen.Insert (Text);
            Queue.Append (Text);
         end if;
      end Consider;
   begin
      declare
         Start : MIU.Buffer;
         Start_Length : MIU.Length_Range;
      begin
         Load ("MI", Start, Start_Length);
         Consider (Start, Start_Length);
      end;

      while Head <= Queue.Last_Index loop
         declare
            Text : constant String := Queue (Head);
            Source, Result : MIU.Buffer;
            Source_Length, Result_Length : MIU.Length_Range;
            Status : MIU.Status_Kind;
         begin
            Head := Head + 1;
            Load (Text, Source, Source_Length);
            for Rule in MIU.Rule_Kind loop
               if Rule in MIU.Add_U | MIU.Double then
                  MIU.Transform
                    (Source, Source_Length, Rule, 0, Result, Result_Length, Status);
                  if Status = MIU.Ok then
                     Consider (Result, Result_Length);
                  end if;
               else
                  for Position in 1 .. Source_Length loop
                     MIU.Transform
                       (Source, Source_Length, Rule, Position,
                        Result, Result_Length, Status);
                     if Status = MIU.Ok then
                        Consider (Result, Result_Length);
                     end if;
                  end loop;
               end if;
            end loop;
         end;
      end loop;

      Put_Line ("reachable" & Seen.Length'Image);
      pragma Assert (Seen.Length > 20, "search stopped too early");
      pragma Assert (not Seen.Contains ("MU"), "MU was stored");
   end Search;
begin
   Check (MIU.Exported_Max = MIU.Max_Length, "max");
   Check (MIU.Exported_Max_History = MIU.Max_History, "history max");
   Check (MIU.Chars_Address /= System.Null_Address, "chars");
   Check (MIU.Meta_Address /= System.Null_Address, "meta");
   Check (MIU.Ready_Address /= System.Null_Address, "ready");
   Check (MIU.Pos_Count_Address /= System.Null_Address, "pos count");
   Check (MIU.Positions_Address /= System.Null_Address, "positions");
   Check (MIU.Hist_Len_Address /= System.Null_Address, "hist len addr");
   Check (MIU.Hist_Chars_Address /= System.Null_Address, "hist chars");

   Expect (MIU.Add_U, 0, "MI", "MIU");
   Expect (MIU.Double, 0, "MI", "MII");
   Expect (MIU.Double, 0, "MIU", "MIUIU");
   Expect (MIU.Triple_I, 2, "MIII", "MU");
   Expect (MIU.Triple_I, 2, "MIIII", "MUI");
   Expect (MIU.Triple_I, 3, "MIIII", "MIU");
   Expect (MIU.Triple_I, 3, "MIIIIU", "MIUU");
   Expect (MIU.Triple_I, 2, "MIIIIU", "MUIU");
   Expect (MIU.Drop_UU, 3, "MIUU", "MI");
   Expect (MIU.Drop_UU, 2, "MUUU", "MU");
   Expect (MIU.Drop_UU, 3, "MUUU", "MU");
   Expect (MIU.Triple_I, 1, "III", "U");
   Expect (MIU.Drop_UU, 1, "UU", "");
   Expect_Bad (MIU.Add_U, 0, "MIU", MIU.Cannot);
   Expect_Bad (MIU.Add_U, 1, "MI", MIU.Bad_Position);
   Expect_Bad (MIU.Double, 0, "M", MIU.Cannot);
   Expect_Bad (MIU.Double, 0, "IU", MIU.Cannot);
   Expect_Bad (MIU.Triple_I, 1, "MIIII", MIU.Bad_Position);
   Expect_Bad (MIU.Triple_I, 4, "MIIII", MIU.Bad_Position);
   Expect_Bad (MIU.Triple_I, 1, "MI", MIU.Cannot);
   Expect_Bad (MIU.Drop_UU, 1, "MI", MIU.Cannot);
   Expect_Bad (MIU.Drop_UU, 0, "MIUU", MIU.Bad_Position);

   declare
      Full : constant String (1 .. MIU.Max_Length) := (others => 'I');
      Wide : constant String := "M" & (1 .. 40 => 'I');
   begin
      Expect_Bad (MIU.Add_U, 0, Full, MIU.Too_Long);
      Expect_Bad (MIU.Double, 0, Wide, MIU.Too_Long);
   end;

   MIU.Reset_Exported;
   Check_Session ("MI");
   Check (MIU.Rule_Ready (MIU.Add_U), "add ready");
   Check (MIU.Rule_Ready (MIU.Double), "double ready");
   Check (not MIU.Rule_Ready (MIU.Triple_I), "triple quiet");
   Check (not MIU.Rule_Ready (MIU.Drop_UU), "drop quiet");
   Check (MIU.I_Count = 1, "start i");

   MIU.Apply_Exported (2, 0);
   Check_Session ("MII");
   MIU.Apply_Exported (2, 0);
   Check_Session ("MIIII");
   Check (MIU.Candidate_Count (MIU.Triple_I) = 2, "two spots");
   Check (MIU.Candidate_At (MIU.Triple_I, 1) = 2, "spot 2");
   Check (MIU.Candidate_At (MIU.Triple_I, 2) = 3, "spot 3");
   Check (MIU.Resolve_Exported (3, 2) = 2, "tap 2");
   Check (MIU.Resolve_Exported (3, 3) = 3, "tap 3");
   Check (MIU.Resolve_Exported (3, 4) = 3, "tap 4");
   Check (MIU.Resolve_Exported (3, 5) = 3, "tap 5");
   Check (MIU.Resolve_Exported (3, 1) = 0, "tap 1");
   Check (MIU.Resolve_Tap (MIU.Triple_I, 4) = 3, "resolve ada");

   MIU.Apply_Exported (1, 0);
   Check_Session ("MIIIIU");
   Check (MIU.Candidate_Count (MIU.Triple_I) = 2, "two spots before U");
   MIU.Apply_Exported (3, MIU.Resolve_Exported (3, 5));
   Check_Session ("MIUU");
   Check (MIU.I_Count = 1, "one I left");
   Check (MIU.I_Count mod 3 /= 0, "not a multiple");
   Check (MIU.Rule_Ready (MIU.Drop_UU), "uu ready");
   Check (MIU.Candidate_At (MIU.Drop_UU, 1) = 3, "uu at 3");
   MIU.Apply_Exported (4, 3);
   Check_Session ("MI");
   Check (MIU.History_Count = 6, "six steps");

   MIU.Undo_Exported;
   Check_Session ("MIUU");
   for Step in 1 .. 4 loop
      MIU.Undo_Exported;
   end loop;
   Check_Session ("MI");
   Check (MIU.History_Count = 1, "back to start");
   MIU.Undo_Exported;
   Check (MIU.Last_Status = MIU.Cannot_Undo, "no undo");
   Check (Current = "MI", "undo kept MI");
   Check (MIU.Meta_At (4) = 5, "undo code");

   MIU.Reset_Exported;
   MIU.Apply_Exported (9, 0);
   Check (MIU.Last_Status = MIU.Bad_Rule, "bad rule");
   Check (Current = "MI", "bad rule keeps MI");
   MIU.Apply_Exported (4, -1);
   Check (MIU.Last_Status = MIU.Bad_Position, "negative");
   Check (Current = "MI", "negative keeps MI");
   MIU.Apply_Exported (4, 1);
   Check (MIU.Last_Status = MIU.Cannot, "no uu");
   Check (MIU.History_Count = 1, "failed apply is not a step");

   Search;

   if Failures = 0 then
      Put_Line ("OK");
   else
      Put_Line ("FAIL" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Smoke;
