package body Crab is

   type Pitch_Line is array (0 .. Max_Notes - 1) of Integer;

   --  Original eight-note lines, one for each starter word. 0 sits on the
   --  bottom line. None of them reads the same backwards.
   Catalog : constant array (0 .. Melody_Count - 1) of Pitch_Line :=
     (0 => (0, 1, 2, 3, 4, 5, 6, 4),
      1 => (0, 3, 6, 5, 2, 4, 1, 2),
      2 => (1, 1, 2, 4, 6, 5, 3, 0));

   Letters      : array (0 .. Max_Tiles - 1) of Integer := (others => 0);
   Pitches      : Pitch_Line := Catalog (0);
   Mirrors      : Pitch_Line := (4, 6, 5, 4, 3, 2, 1, 0);
   Shown        : Natural := 0;
   Melody_Index : Natural := 0;
   Play_Beat    : Integer := -1;
   Meta         : array (1 .. 10) of Integer := (others => 0);

   function Letter (Index : Natural) return Natural is
   begin
      if Index >= Max_Tiles or else Letters (Index) < 0 then
         return 0;
      end if;
      return Natural (Letters (Index));
   end Letter;

   function Note (Index : Natural) return Natural is
   begin
      if Index >= Max_Notes or else Pitches (Index) < 0 then
         return 0;
      end if;
      return Natural (Pitches (Index));
   end Note;

   function Mirror_Note (Index : Natural) return Natural is
   begin
      if Index >= Max_Notes or else Mirrors (Index) < 0 then
         return 0;
      end if;
      return Natural (Mirrors (Index));
   end Mirror_Note;

   function Fold (C : Character) return Character is
      P : constant Natural := Character'Pos (C);
   begin
      if C in 'A' .. 'Z' then
         return C;
      elsif C in 'a' .. 'z' then
         return Character'Val (Character'Pos (C) - 32);
      end if;
      case P is
         when 192 | 193 | 194 | 195 | 196 | 224 | 225 | 226 | 227 | 228 =>
            return 'A';
         when 200 | 201 | 202 | 203 | 232 | 233 | 234 | 235 =>
            return 'E';
         when 204 | 205 | 206 | 207 | 236 | 237 | 238 | 239 =>
            return 'I';
         when 210 | 211 | 212 | 213 | 214 | 242 | 243 | 244 | 245 | 246 =>
            return 'O';
         when 217 | 218 | 219 | 220 | 249 | 250 | 251 | 252 =>
            return 'U';
         when 199 | 231 =>
            return 'C';
         when 209 | 241 =>
            return 'N';
         when 221 | 253 | 255 =>
            return 'Y';
         when others =>
            return ASCII.NUL;
      end case;
   end Fold;

   procedure Normalise (Text : String; Into : out String; Last : out Natural) is
      Len : Natural := 0;

      procedure Push (C : Character) is
      begin
         if Len < Into'Length then
            Len := Len + 1;
            Into (Into'First + Len - 1) := C;
         end if;
      end Push;
   begin
      for C of Text loop
         if Character'Pos (C) = 223 then
            Push ('S');
            Push ('S');
         else
            declare
               Base : constant Character := Fold (C);
            begin
               if Base /= ASCII.NUL then
                  Push (Base);
               end if;
            end;
         end if;
      end loop;
      Last := Len;
   end Normalise;

   procedure Reverse_Copy (Text : String; Into : out String) is
      Count : constant Natural := Natural'Min (Text'Length, Into'Length);
   begin
      for I in 1 .. Count loop
         Into (Into'First + I - 1) := Text (Text'Last + 1 - I);
      end loop;
   end Reverse_Copy;

   function Palindrome (Text : String) return Boolean is
      Plain : String (1 .. 1024);
      Last  : Natural;
   begin
      Normalise (Text, Plain, Last);
      for I in 1 .. Last loop
         if Plain (I) /= Plain (Last + 1 - I) then
            return False;
         end if;
      end loop;
      return True;
   end Palindrome;

   function Is_Palindrome return Boolean is
      Buf : String (1 .. Max_Tiles) := (others => ' ');
      Len : Natural := 0;
   begin
      for I in Letters'Range loop
         if Letters (I) > 0 and then Letters (I) <= 255 then
            Len := Len + 1;
            Buf (Len) := Character'Val (Letters (I));
         end if;
      end loop;
      return Palindrome (Buf);
   end Is_Palindrome;

   procedure Retrograde (Source : Melody; Result : out Melody) is
   begin
      for I in Source'Range loop
         Result (I) := Source (Max_Notes + 1 - I);
      end loop;
   end Retrograde;

   function Shown_Length return Natural is (Shown);

   function Step_Milliseconds return Natural is (Step_Ms);

   function Play_Column (Voice : Natural; Beat : Natural) return Integer is
      Slot : constant Natural := Beat mod Max_Notes;
   begin
      if Voice > 1 then
         return -1;
      end if;
      return Integer (Slot);
   end Play_Column;

   procedure Publish is
      Source, Back : Melody;
   begin
      Meta (1) := Integer (Shown);
      Meta (2) := (if Is_Palindrome then 1 else 0);
      Meta (3) := Max_Notes;
      Meta (4) := Pitch_Max;
      Meta (5) := Melody_Count;
      Meta (6) := Integer (Melody_Index);
      Meta (7) := Step_Ms;
      Meta (8) := Play_Beat;
      if Play_Beat < 0 then
         Meta (9) := -1;
         Meta (10) := -1;
      else
         Meta (9) := Play_Column (0, Natural (Play_Beat));
         Meta (10) := Play_Column (1, Natural (Play_Beat));
      end if;
      for I in Source'Range loop
         Source (I) := Natural (Pitches (I - 1));
      end loop;
      Retrograde (Source, Back);
      for I in Back'Range loop
         Mirrors (I - 1) := Integer (Back (I));
      end loop;
   end Publish;

   procedure Clear_Letters is
   begin
      Letters := (others => 0);
      Shown := 0;
      Publish;
   end Clear_Letters;

   procedure Set_Letter (Index : Natural; Code : Natural) is
   begin
      if Index >= Max_Tiles then
         return;
      end if;
      if Code > 255 then
         Letters (Index) := 0;
      else
         Letters (Index) := Integer (Code);
      end if;
      if Index >= Shown then
         Shown := Index + 1;
      end if;
      Publish;
   end Set_Letter;

   procedure Cycle_Letter (Index : Natural) is
      Code : Natural;
      Base : Character;
   begin
      if Index >= Max_Tiles then
         return;
      end if;
      Code := Letter (Index);
      if Code = 0 then
         Letters (Index) := Character'Pos ('A');
      else
         Base := Fold (Character'Val (Code));
         if Base = ASCII.NUL then
            Letters (Index) := Character'Pos ('A');
         elsif Base = 'Z' then
            Letters (Index) := 0;
         else
            Letters (Index) := Character'Pos (Base) + 1;
         end if;
      end if;
      Publish;
   end Cycle_Letter;

   procedure Set_Text (Text : String) is
      Slot : Natural := 0;
   begin
      Letters := (others => 0);
      for C of Text loop
         exit when Slot >= Max_Tiles;
         Letters (Slot) := Character'Pos (C);
         Slot := Slot + 1;
      end loop;
      Shown := Slot;
      Publish;
   end Set_Text;

   procedure Cycle_Note (Index : Natural) is
   begin
      if Index >= Max_Notes then
         return;
      end if;
      Pitches (Index) := (Pitches (Index) + 1) mod (Pitch_Max + 1);
      Publish;
   end Cycle_Note;

   procedure Select_Melody (Index : Natural) is
   begin
      Melody_Index := Index mod Melody_Count;
      Pitches := Catalog (Melody_Index);
      Publish;
   end Select_Melody;

   procedure Set_Beat (Beat : Integer) is
   begin
      if Beat < 0 then
         Play_Beat := -1;
      else
         Play_Beat := Integer (Natural (Beat) mod Max_Notes);
      end if;
      Publish;
   end Set_Beat;

   procedure Reset is
   begin
      Letters := (others => 0);
      Shown := 0;
      Select_Melody (0);
   end Reset;

   function Meta_Address return System.Address is (Meta'Address);
   function Letter_Address return System.Address is (Letters'Address);
   function Note_Address return System.Address is (Pitches'Address);
   function Mirror_Address return System.Address is (Mirrors'Address);

   procedure Reset_Exported is
   begin
      Reset;
   end Reset_Exported;

   procedure Clear_Exported is
   begin
      Clear_Letters;
   end Clear_Exported;

   procedure Set_Letter_Exported (Index : Integer; Code : Integer) is
   begin
      if Index < 0 or else Code < 0 then
         return;
      end if;
      Set_Letter (Natural (Index), Natural (Code));
   end Set_Letter_Exported;

   procedure Cycle_Letter_Exported (Index : Integer) is
   begin
      if Index < 0 then
         return;
      end if;
      Cycle_Letter (Natural (Index));
   end Cycle_Letter_Exported;

   procedure Cycle_Note_Exported (Index : Integer) is
   begin
      if Index < 0 then
         return;
      end if;
      Cycle_Note (Natural (Index));
   end Cycle_Note_Exported;

   procedure Select_Melody_Exported (Index : Integer) is
   begin
      if Index < 0 then
         Select_Melody (0);
      else
         Select_Melody (Natural (Index));
      end if;
   end Select_Melody_Exported;

   procedure Set_Beat_Exported (Beat : Integer) is
   begin
      Set_Beat (Beat);
   end Set_Beat_Exported;

end Crab;
