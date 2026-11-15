--  MIU block rules. The browser calls the exported subprograms; it does not
--  decide whether a rule fits. Positions are 1-based indexes of the first
--  block of a match. Rules that act on the whole string take position 0.
--
--  Starting from MI, the number of I blocks is never a multiple of 3:
--  adding U and deleting UU keep it, doubling the tail doubles it, and
--  replacing III by U subtracts 3. MU has no I blocks, so it stays out
--  of reach. The native test checks that by searching.

with System;

package MIU is

   Max_Length  : constant := 64;
   Max_History : constant := 64;

   subtype Length_Range is Natural range 0 .. Max_Length;
   type Buffer is array (1 .. Max_Length) of Character;

   type Rule_Kind is (Add_U, Double, Triple_I, Drop_UU);

   type Status_Kind is
     (Ok, Bad_Rule, Cannot, Bad_Position, Too_Long, Cannot_Undo);

   procedure Transform
     (Source        : Buffer;
      Source_Length : Length_Range;
      Rule          : Rule_Kind;
      Position      : Natural;
      Result        : out Buffer;
      Result_Length : out Length_Range;
      Status        : out Status_Kind);

   procedure Reset;
   procedure Apply (Rule : Rule_Kind; Position : Natural);
   procedure Undo;

   function Current_Length return Length_Range;
   function Current_Symbol (Index : Positive) return Character;
   function I_Count return Natural;
   function History_Count return Natural;
   function History_Step_Length (Step : Positive) return Length_Range;
   function History_Symbol (Step : Positive; Index : Positive) return Character;
   function Last_Status return Status_Kind;
   function Rule_Ready (Rule : Rule_Kind) return Boolean;
   function Candidate_Count (Rule : Rule_Kind) return Natural;
   function Candidate_At (Rule : Rule_Kind; Nth : Positive) return Natural;
   function Resolve_Tap (Rule : Rule_Kind; Tap : Natural) return Natural;
   function Meta_At (Index : Positive) return Integer;

   function Exported_Max return Integer
     with Export, Convention => C, External_Name => "miu_max_length";
   function Exported_Max_History return Integer
     with Export, Convention => C, External_Name => "miu_max_history";
   function Chars_Address return System.Address
     with Export, Convention => C, External_Name => "miu_chars";
   function Meta_Address return System.Address
     with Export, Convention => C, External_Name => "miu_meta";
   function Ready_Address return System.Address
     with Export, Convention => C, External_Name => "miu_ready";
   function Pos_Count_Address return System.Address
     with Export, Convention => C, External_Name => "miu_pos_count";
   function Positions_Address return System.Address
     with Export, Convention => C, External_Name => "miu_positions";
   function Hist_Len_Address return System.Address
     with Export, Convention => C, External_Name => "miu_hist_len";
   function Hist_Chars_Address return System.Address
     with Export, Convention => C, External_Name => "miu_hist_chars";

   procedure Reset_Exported
     with Export, Convention => C, External_Name => "miu_reset";
   procedure Apply_Exported (Rule : Integer; Position : Integer)
     with Export, Convention => C, External_Name => "miu_apply";
   procedure Undo_Exported
     with Export, Convention => C, External_Name => "miu_undo";
   function Resolve_Exported (Rule : Integer; Tap : Integer) return Integer
     with Export, Convention => C, External_Name => "miu_resolve";

end MIU;
