with Ada.Command_Line;
with Ada.Text_IO;
with Crab;

procedure Crab_Smoke is
   use Ada.Text_IO;

   type Word is mod 2**32;

   Failures : Natural := 0;
   Seed     : Word := 1;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Put_Line ("FAIL " & Message);
      end if;
   end Check;

   function Next_Rand return Natural is
   begin
      Seed := Seed * 1664525 + 1013904223;
      return Natural (Seed mod 2_147_483_647);
   end Next_Rand;
   function Same (Left : String; Right : String) return Boolean is
     (Left'Length = Right'Length and then Left = Right);
begin
   declare
      Empty_In  : String (1 .. 0);
      Empty_Out : String (1 .. 0);
      Pair  : String (1 .. 2);
      Back  : String (1 .. 5);
      Twice : String (1 .. 5);
      Plain : String (1 .. 64);
      Last  : Natural;
   begin
      Crab.Reverse_Copy (Empty_In, Empty_Out);
      Check (Empty_Out'Length = 0, "empty reverse");
      Crab.Reverse_Copy ("AB", Pair);
      Check (Pair = "BA", "two letters");
      Crab.Reverse_Copy ("kayak", Back);
      Crab.Reverse_Copy (Back, Twice);
      Check (Twice = "kayak", "reverse twice");
      Crab.Normalise ("A man, a plan, a canal: Panama", Plain, Last);
      Check (Same (Plain (1 .. Last), "AMANAPLANACANALPANAMA"), "famous line");
   end;
   Check (Crab.Palindrome ("A man, a plan, a canal: Panama"), "famous palindrome");
   Check (Crab.Palindrome ("Kayak"), "kayak");
   Check (Crab.Palindrome ("Été"), "ete with accents");
   Check (Crab.Palindrome ("aßa"), "eszett folds to ss");
   Check (not Crab.Palindrome ("baß"), "bass is not a palindrome");
   Check (not Crab.Palindrome ("crab"), "crab is not a palindrome");
   Check (Crab.Palindrome (""), "empty is a palindrome");
   Check (Crab.Palindrome ("!!"), "marks drop out");

   Crab.Reset;
   Check (Crab.Is_Palindrome, "blank row reads both ways");
   Crab.Set_Text ("RADAR");
   Check (Crab.Is_Palindrome, "radar");
   Check (Crab.Letter (0) = Character'Pos ('R'), "first tile");
   Check (Crab.Letter (4) = Character'Pos ('R'), "last tile");
   Crab.Cycle_Letter (0);
   Check (not Crab.Is_Palindrome, "one change breaks it");
   Check (Crab.Letter (0) = Character'Pos ('S'), "R cycles to S");
   Crab.Set_Letter (0, Character'Pos ('Z'));
   Crab.Cycle_Letter (0);
   Check (Crab.Letter (0) = 0, "Z cycles to a gap");
   Crab.Cycle_Letter (0);
   Check (Crab.Letter (0) = Character'Pos ('A'), "a gap cycles to A");

   Check (Crab.Note (0) = 0, "first note");
   Check (Crab.Mirror_Note (0) = Crab.Note (7), "the end mirrors the start");
   Check (Crab.Mirror_Note (3) = Crab.Note (4), "the middle pair mirrors");
   Crab.Cycle_Note (0);
   Check (Crab.Note (0) = 1, "pitch steps");
   Check (Crab.Mirror_Note (7) = 1, "the mirror hears the new pitch");
   for Step in 1 .. 6 loop
      Crab.Cycle_Note (0);
   end loop;
   Check (Crab.Note (0) = 0, "pitch wraps");

   Crab.Set_Text ("KAYAK");
   Check (Crab.Shown_Length = 5, "kayak shows five tiles");
   Crab.Set_Letter (4, 0);
   Check (Crab.Shown_Length = 5, "a blank letter keeps its slot");
   Crab.Set_Text ("OTTO");
   Check (Crab.Shown_Length = 4, "otto shows four tiles");
   Crab.Clear_Letters;
   Check (Crab.Shown_Length = 0, "an empty row shows no tiles");

   declare
      Source : Crab.Melody;
      Once   : Crab.Melody;
      Twice  : Crab.Melody;
      Saved  : array (0 .. Crab.Max_Notes - 1) of Natural;
   begin
      for Trial in 1 .. 60 loop
         for I in Source'Range loop
            Source (I) := Next_Rand mod 256;
         end loop;
         Crab.Retrograde (Source, Once);
         for I in Source'Range loop
            Check (Once (I) = Source (Crab.Max_Notes + 1 - I), "retrograde place");
         end loop;
         Crab.Retrograde (Once, Twice);
         for I in Source'Range loop
            Check (Twice (I) = Source (I), "retrograde twice");
         end loop;
      end loop;

      Crab.Select_Melody (1);
      for I in 0 .. Crab.Max_Notes - 1 loop
         Check (Crab.Mirror_Note (I) = Crab.Note (Crab.Max_Notes - 1 - I),
                "stored line is a retrograde");
         Saved (I) := Crab.Note (I);
      end loop;
      Crab.Select_Melody (1 + Crab.Melody_Count);
      for I in Saved'Range loop
         Check (Crab.Note (I) = Saved (I), "melody index wraps");
      end loop;
      Crab.Select_Melody (0);
      Check (Crab.Note (2) /= Saved (2), "the tunes are different");
   end;

   for Trial in 1 .. 80 loop
      declare
         Len  : constant Natural := 1 + Next_Rand mod 20;
         Item : String (1 .. Len);
      begin
         for I in Item'Range loop
            Item (I) := Character'Val (Next_Rand mod 256);
         end loop;
         declare
            Folded : String (1 .. Item'Length * 2);
            Last   : Natural;
            Back   : String (1 .. Item'Length);
            Again  : String (1 .. Item'Length);
            Flip   : String (1 .. Item'Length * 2);
            Twice  : String (1 .. Item'Length * 2);
         begin
            Crab.Reverse_Copy (Item, Back);
            Crab.Reverse_Copy (Back, Again);
            Check (Again = Item, "any string");
            Crab.Normalise (Item, Folded, Last);
            Crab.Reverse_Copy (Folded (1 .. Last), Flip (1 .. Last));
            Crab.Reverse_Copy (Flip (1 .. Last), Twice (1 .. Last));
            Check (Same (Twice (1 .. Last), Folded (1 .. Last)), "folded string");
            Check (Crab.Palindrome (Item) = Same (Folded (1 .. Last), Flip (1 .. Last)),
                   "check matches reverse");
         end;
      end;
   end loop;

   if Failures = 0 then
      Put_Line ("crab smoke ok");
   else
      Put_Line ("crab smoke failed:" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Crab_Smoke;
