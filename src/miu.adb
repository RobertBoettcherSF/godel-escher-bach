package body MIU is

   Cur         : Buffer       := (others => Character'Val (0));
   Cur_Len     : Length_Range := 0;
   Hist_Count  : Natural      := 0;
   Err         : Status_Kind  := Ok;
   Last_Rule   : Integer      := 0;
   Last_Pos    : Integer      := 0;
   Prev_Len    : Integer      := 0;

   Hist_Lens  : array (1 .. Max_History) of Length_Range := (others => 0);
   Hist_Chars : array (1 .. Max_History, 1 .. Max_Length) of Character :=
     (others => (others => Character'Val (0)));

   Meta      : array (1 .. 8) of Integer := (others => 0);
   Ready     : array (1 .. 4) of Integer := (others => 0);
   Pos_Count : array (1 .. 4) of Integer := (others => 0);
   Positions : array (1 .. 4, 1 .. Max_Length) of Integer :=
     (others => (others => 0));

   function Status_Code (Status : Status_Kind) return Integer is
   begin
      case Status is
         when Ok =>
            return 0;
         when Bad_Rule =>
            return 1;
         when Cannot =>
            return 2;
         when Bad_Position =>
            return 3;
         when Too_Long =>
            return 4;
         when Cannot_Undo =>
            return 5;
      end case;
   end Status_Code;

   function Exported_Max return Integer is (Max_Length);
   function Exported_Max_History return Integer is (Max_History);
   function Chars_Address return System.Address is (Cur'Address);
   function Meta_Address return System.Address is (Meta'Address);
   function Ready_Address return System.Address is (Ready'Address);
   function Pos_Count_Address return System.Address is (Pos_Count'Address);
   function Positions_Address return System.Address is (Positions'Address);
   function Hist_Len_Address return System.Address is (Hist_Lens'Address);
   function Hist_Chars_Address return System.Address is (Hist_Chars'Address);

   function Current_Length return Length_Range is (Cur_Len);

   function Current_Symbol (Index : Positive) return Character is
   begin
      if Index > Cur_Len then
         return Character'Val (0);
      end if;
      return Cur (Index);
   end Current_Symbol;

   function I_Count return Natural is
      Total : Natural := 0;
   begin
      for Index in 1 .. Cur_Len loop
         if Cur (Index) = 'I' then
            Total := Total + 1;
         end if;
      end loop;
      return Total;
   end I_Count;

   function History_Count return Natural is (Hist_Count);

   function History_Step_Length (Step : Positive) return Length_Range is
   begin
      if Step > Hist_Count then
         return 0;
      end if;
      return Hist_Lens (Step);
   end History_Step_Length;

   function History_Symbol (Step : Positive; Index : Positive) return Character is
   begin
      if Step > Hist_Count or else Index > Max_Length then
         return Character'Val (0);
      end if;
      return Hist_Chars (Step, Index);
   end History_Symbol;

   function Last_Status return Status_Kind is (Err);

   function Meta_At (Index : Positive) return Integer is
   begin
      if Index > Meta'Last then
         return -1;
      end if;
      return Meta (Index);
   end Meta_At;

   function Rule_Index (Rule : Rule_Kind) return Positive is
     (Rule_Kind'Pos (Rule) + 1);

   function Has_Run
     (Source        : Buffer;
      Source_Length : Length_Range;
      Item          : String) return Boolean;

   procedure Transform
     (Source        : Buffer;
      Source_Length : Length_Range;
      Rule          : Rule_Kind;
      Position      : Natural;
      Result        : out Buffer;
      Result_Length : out Length_Range;
      Status        : out Status_Kind)
   is
      procedure Fail (Code : Status_Kind) is
      begin
         Result := (others => Character'Val (0));
         Result_Length := 0;
         Status := Code;
      end Fail;

      function Match (From : Positive; Item : String) return Boolean is
      begin
         if From + Item'Length - 1 > Source_Length then
            return False;
         end if;
         for Offset in Item'Range loop
            if Source (From + Offset - Item'First) /= Item (Offset) then
               return False;
            end if;
         end loop;
         return True;
      end Match;
   begin
      case Rule is
         when Add_U =>
            if Source_Length = 0 or else Source (Source_Length) /= 'I' then
               Fail (Cannot);
            elsif Source_Length = Max_Length then
               Fail (Too_Long);
            elsif Position /= 0 then
               Fail (Bad_Position);
            else
               Result := (others => Character'Val (0));
               Result (1 .. Source_Length) := Source (1 .. Source_Length);
               Result (Source_Length + 1) := 'U';
               Result_Length := Source_Length + 1;
               Status := Ok;
            end if;

         when Double =>
            declare
               Tail    : Natural;
               New_Len : Natural;
            begin
               if Source_Length = 0 or else Source (1) /= 'M' then
                  Fail (Cannot);
               else
                  Tail := Source_Length - 1;
                  New_Len := 1 + 2 * Tail;
                  if Tail = 0 then
                     Fail (Cannot);
                  elsif New_Len > Max_Length then
                     Fail (Too_Long);
                  elsif Position /= 0 then
                     Fail (Bad_Position);
                  else
                     Result := (others => Character'Val (0));
                     Result (1) := 'M';
                     Result (2 .. 1 + Tail) := Source (2 .. Source_Length);
                     Result (2 + Tail .. New_Len) := Source (2 .. Source_Length);
                     Result_Length := New_Len;
                     Status := Ok;
                  end if;
               end if;
            end;

         when Triple_I =>
            if Source_Length < 3 or else not Has_Run (Source, Source_Length, "III") then
               Fail (Cannot);
            elsif Position = 0
              or else Position + 2 > Source_Length
              or else not Match (Position, "III")
            then
               Fail (Bad_Position);
            else
               declare
                  New_Len : constant Natural := Source_Length - 2;
                  Tail    : constant Natural := Source_Length - (Position + 2);
               begin
                  Result := (others => Character'Val (0));
                  if Position > 1 then
                     Result (1 .. Position - 1) := Source (1 .. Position - 1);
                  end if;
                  Result (Position) := 'U';
                  if Tail > 0 then
                     Result (Position + 1 .. Position + Tail) :=
                       Source (Position + 3 .. Source_Length);
                  end if;
                  Result_Length := New_Len;
                  Status := Ok;
               end;
            end if;

         when Drop_UU =>
            if Source_Length < 2 or else not Has_Run (Source, Source_Length, "UU") then
               Fail (Cannot);
            elsif Position = 0
              or else Position + 1 > Source_Length
              or else not Match (Position, "UU")
            then
               Fail (Bad_Position);
            else
               declare
                  New_Len : constant Natural := Source_Length - 2;
                  Tail    : constant Natural := Source_Length - (Position + 1);
               begin
                  Result := (others => Character'Val (0));
                  if Position > 1 then
                     Result (1 .. Position - 1) := Source (1 .. Position - 1);
                  end if;
                  if Tail > 0 then
                     Result (Position .. Position + Tail - 1) :=
                       Source (Position + 2 .. Source_Length);
                  end if;
                  Result_Length := New_Len;
                  Status := Ok;
               end;
            end if;
      end case;
   end Transform;

   function Has_Run
     (Source        : Buffer;
      Source_Length : Length_Range;
      Item          : String) return Boolean
   is
   begin
      if Source_Length < Item'Length then
         return False;
      end if;
      for From in 1 .. Source_Length - Item'Length + 1 loop
         declare
            Fits : Boolean := True;
         begin
            for Offset in Item'Range loop
               if Source (From + Offset - Item'First) /= Item (Offset) then
                  Fits := False;
               end if;
            end loop;
            if Fits then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Has_Run;

   function Rule_Ready (Rule : Rule_Kind) return Boolean is
     (Ready (Rule_Index (Rule)) /= 0);

   function Candidate_Count (Rule : Rule_Kind) return Natural is
     (Natural (Pos_Count (Rule_Index (Rule))));

   function Candidate_At (Rule : Rule_Kind; Nth : Positive) return Natural is
      Slot : constant Positive := Rule_Index (Rule);
   begin
      if Nth > Natural (Pos_Count (Slot)) or else Positions (Slot, Nth) < 1 then
         return 0;
      end if;
      return Natural (Positions (Slot, Nth));
   end Candidate_At;

   function Resolve_Tap (Rule : Rule_Kind; Tap : Natural) return Natural is
      Span : Natural;
      Best : Natural := 0;
      Slot : Positive;
   begin
      case Rule is
         when Triple_I =>
            Span := 3;
         when Drop_UU =>
            Span := 2;
         when Add_U | Double =>
            return 0;
      end case;
      if Tap = 0 then
         return 0;
      end if;
      Slot := Rule_Index (Rule);
      for Nth in 1 .. Natural (Pos_Count (Slot)) loop
         declare
            Start : constant Integer := Positions (Slot, Nth);
         begin
            if Start > 0
              and then Tap >= Natural (Start)
              and then Tap <= Natural (Start) + Span - 1
            then
               if Tap = Natural (Start) then
                  return Natural (Start);
               elsif Natural (Start) > Best then
                  Best := Natural (Start);
               end if;
            end if;
         end;
      end loop;
      return Best;
   end Resolve_Tap;

   procedure Refresh is
      Scratch : Buffer;
      Scratch_Len : Length_Range;
      Status : Status_Kind;
   begin
      for Slot in Ready'Range loop
         Ready (Slot) := 0;
         Pos_Count (Slot) := 0;
         for Index in Positions'Range (2) loop
            Positions (Slot, Index) := 0;
         end loop;
      end loop;

      Transform (Cur, Cur_Len, Add_U, 0, Scratch, Scratch_Len, Status);
      if Status = Ok then
         Ready (1) := 1;
      end if;
      Transform (Cur, Cur_Len, Double, 0, Scratch, Scratch_Len, Status);
      if Status = Ok then
         Ready (2) := 1;
      end if;

      for Rule in Triple_I .. Drop_UU loop
         declare
            Slot  : constant Positive := Rule_Index (Rule);
            Found : Natural := 0;
         begin
            for Index in 1 .. Cur_Len loop
               Transform (Cur, Cur_Len, Rule, Index, Scratch, Scratch_Len, Status);
               if Status = Ok then
                  Found := Found + 1;
                  Positions (Slot, Found) := Index;
               end if;
            end loop;
            Pos_Count (Slot) := Found;
            if Found > 0 then
               Ready (Slot) := 1;
            end if;
         end;
      end loop;

      Meta (1) := Integer (Cur_Len);
      Meta (2) := Integer (I_Count);
      Meta (3) := Integer (Hist_Count);
      Meta (4) := Status_Code (Err);
      Meta (5) := Last_Rule;
      Meta (6) := Last_Pos;
      Meta (7) := Prev_Len;
      Meta (8) := 0;
   end Refresh;

   procedure Remember is
   begin
      if Hist_Count = Max_History then
         for Step in 1 .. Max_History - 1 loop
            Hist_Lens (Step) := Hist_Lens (Step + 1);
            for Index in 1 .. Max_Length loop
               Hist_Chars (Step, Index) := Hist_Chars (Step + 1, Index);
            end loop;
         end loop;
         Hist_Count := Max_History - 1;
      end if;
      Hist_Count := Hist_Count + 1;
      Hist_Lens (Hist_Count) := Cur_Len;
      for Index in 1 .. Max_Length loop
         Hist_Chars (Hist_Count, Index) := Cur (Index);
      end loop;
   end Remember;

   procedure Reset is
   begin
      Cur := (others => Character'Val (0));
      Cur (1) := 'M';
      Cur (2) := 'I';
      Cur_Len := 2;
      Hist_Count := 0;
      Err := Ok;
      Last_Rule := 0;
      Last_Pos := 0;
      Prev_Len := 2;
      Remember;
      Refresh;
   end Reset;

   procedure Apply (Rule : Rule_Kind; Position : Natural) is
      Result : Buffer;
      Result_Length : Length_Range;
      Status : Status_Kind;
   begin
      Transform (Cur, Cur_Len, Rule, Position, Result, Result_Length, Status);
      if Status /= Ok then
         Err := Status;
         Refresh;
         return;
      end if;
      Prev_Len := Integer (Cur_Len);
      Cur := Result;
      Cur_Len := Result_Length;
      Last_Rule := Rule_Kind'Pos (Rule) + 1;
      Last_Pos := Integer (Position);
      Err := Ok;
      Remember;
      Refresh;
   end Apply;

   procedure Undo is
   begin
      if Hist_Count <= 1 then
         Err := Cannot_Undo;
         Refresh;
         return;
      end if;
      Hist_Count := Hist_Count - 1;
      Cur_Len := Hist_Lens (Hist_Count);
      for Index in 1 .. Max_Length loop
         Cur (Index) := Hist_Chars (Hist_Count, Index);
      end loop;
      Last_Rule := 0;
      Last_Pos := 0;
      Prev_Len := Integer (Cur_Len);
      Err := Ok;
      Refresh;
   end Undo;

   procedure Reset_Exported is
   begin
      Reset;
   end Reset_Exported;

   procedure Apply_Exported (Rule : Integer; Position : Integer) is
   begin
      if Rule < 1 or else Rule > 4 then
         Err := Bad_Rule;
         Refresh;
         return;
      end if;
      if Position < 0 then
         Err := Bad_Position;
         Refresh;
         return;
      end if;
      Apply (Rule_Kind'Val (Rule - 1), Natural (Position));
   end Apply_Exported;

   procedure Undo_Exported is
   begin
      Undo;
   end Undo_Exported;

   function Resolve_Exported (Rule : Integer; Tap : Integer) return Integer is
   begin
      if Rule < 1 or else Rule > 4 or else Tap < 0 then
         return 0;
      end if;
      return Integer (Resolve_Tap (Rule_Kind'Val (Rule - 1), Natural (Tap)));
   end Resolve_Exported;

end MIU;
