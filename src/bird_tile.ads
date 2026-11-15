--  One flying bird on a square, made the classroom way.
--  A square of side 340. Nx shifts the vertical edges (positive is right).
--  Ny shifts the horizontal edges (positive is up). The right edge is the
--  left edge translated by Side. The top edge is the bottom edge translated
--  by Side. Samples run from 0 to 1 along each edge.
--  The tail fan and the beak are the vertical pair. The wing feathers and
--  the belly are the horizontal pair.

package Bird_Tile is

   Side : constant Float := 340.0;

   Sample_Last : constant := 64;

   type Sample_Array is array (0 .. Sample_Last) of Float;

   Nx : constant Sample_Array :=
     (
          0.000,     0.000,     0.000,     0.000,
          0.000,     0.000,     0.000,   -10.770,
        -21.800,   -27.924,   -32.309,   -35.481,
        -37.506,   -38.246,   -37.354,   -34.046,
        -25.348,   -42.748,   -53.147,   -59.393,
        -62.835,   -63.928,   -62.811,   -59.418,
        -53.413,   -43.805,   -30.937,   -27.566,
        -30.789,   -31.724,   -31.277,   -29.848,
        -27.636,   -24.673,   -20.443,   -12.675,
          1.693,     6.597,    11.816,    15.271,
         15.837,    13.343,     8.569,     3.252,
          0.079,     0.095,    13.226,    26.786,
         24.256,    13.479,    17.585,    33.286,
         48.976,    62.094,    70.805,    73.995,
         71.274,    62.973,    50.149,    34.580,
         18.769,     5.938,     0.038,     0.000,
          0.000
     );

   Ny : constant Sample_Array :=
     (
          0.000,     0.676,     2.206,     3.608,
          5.271,     7.153,     9.211,    11.409,
         25.539,    38.860,    46.938,    52.704,
         56.832,    59.545,    60.866,    60.654,
         58.510,    53.287,    44.358,    67.804,
         78.666,    85.436,    89.464,    91.216,
         90.816,    88.149,    82.779,    73.466,
         53.735,    60.425,    67.422,    70.912,
         72.230,    71.821,    69.840,    66.263,
         60.867,    52.986,    39.976,    23.719,
         21.352,    18.953,    16.551,    14.176,
         11.861,     9.641,     7.552,     5.632,
          3.921,     2.463,     1.301,     0.482,
          0.053,     0.000,     0.000,     0.000,
          0.000,     0.000,     0.000,     0.000,
          0.000,     0.000,     0.000,     0.000,
          0.000
     );

   Eye_X : constant Float := 362.00;
   Eye_Y : constant Float := 278.80;
   Eye_R : constant Float := 26.0;
   Pupil_X : constant Float := 371.00;
   Pupil_Y : constant Float := 278.80;
   Pupil_R : constant Float := 10.0;

end Bird_Tile;
