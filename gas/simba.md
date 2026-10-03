# Gas report

Sierra gas (`l2_gas`) per benchmark; `net` = raw - group baseline.

## simba::benches

### real_acosh

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 36620 | 28510 | x1.00 |
| `generic` | 36620 | 28510 | x1.00 |

### real_asinh

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 37600 | 29490 | x1.00 |
| `generic` | 37600 | 29490 | x1.00 |

### real_atanh

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 42760 | 34650 | x1.00 |
| `generic` | 42760 | 34650 | x1.00 |

### real_ceil

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 10020 | 1910 | x1.00 |
| `generic` | 10020 | 1910 | x1.00 |

### real_copysign

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 10270 | 1760 | x1.00 |
| `generic` | 10270 | 1760 | x1.00 |

### real_cross3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 14650 | 5340 | x1.00 |
| `generic` | 14650 | 5340 | x1.00 |

### real_diff_prod

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 11090 | 1780 | x1.00 |
| `named` | 11090 | 1780 | x1.00 |

### real_dot3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 11290 | 1980 | x1.00 |
| `generic` | 11290 | 1980 | x1.00 |

### real_exp2

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 27570 | 19460 | x1.00 |
| `generic` | 27570 | 19460 | x1.00 |

### real_exp_m1

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 30090 | 21980 | x1.00 |
| `generic` | 30090 | 21980 | x1.00 |

### real_fract

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 10390 | 2280 | x1.00 |
| `generic` | 10390 | 2280 | x1.00 |

### real_hypot

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 11030 | 2520 | x1.00 |
| `generic` | 11030 | 2520 | x1.00 |

### real_jacobi_c

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `alt_inv_norm2` | 12950 | 4840 | x1.00 |
| `recip_sqrt` | 14860 | 6750 | x1.39 |

### real_ln_1p

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 28870 | 20760 | x1.00 |
| `generic` | 28870 | 20760 | x1.00 |

### real_log

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 51030 | 42520 | x1.00 |
| `generic` | 51030 | 42520 | x1.00 |

### real_log10

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 28030 | 19920 | x1.00 |
| `generic` | 28030 | 19920 | x1.00 |

### real_log2

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 28030 | 19920 | x1.00 |
| `generic` | 28030 | 19920 | x1.00 |

### real_mul_add

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 11090 | 1780 | x1.00 |
| `named` | 11090 | 1780 | x1.00 |

### real_norm16

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 16050 | 6740 | x1.00 |
| `typed` | 16050 | 6740 | x1.00 |

### real_norm3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 10730 | 2220 | x1.00 |
| `generic` | 10730 | 2220 | x1.00 |

### real_norm6

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 14250 | 4940 | x1.00 |
| `typed` | 14250 | 4940 | x1.00 |

### real_norm9

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 14650 | 5340 | x1.00 |
| `typed` | 14750 | 5440 | x1.02 |

### real_normalize3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `recip` | 16010 | 7500 | x1.00 |
| `div` | 20190 | 11680 | x1.56 |

### real_powf

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 56440 | 47930 | x1.00 |
| `generic` | 56440 | 47930 | x1.00 |

### real_powi

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 10190 | 2080 | x1.00 |
| `generic` | 10190 | 2080 | x1.00 |

### real_round

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 10590 | 2480 | x1.00 |
| `generic` | 10590 | 2480 | x1.00 |

### real_scalar

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `add` | 9150 | 640 | x1.00 |
| `mul` | 10090 | 1580 | x2.47 |
| `sqrt` | 10330 | 1820 | x2.84 |
| `recip` | 11330 | 2820 | x4.41 |
| `div` | 11810 | 3300 | x5.16 |
| `inv_norm2` | 12850 | 4340 | x6.78 |
| `cosh` | 36910 | 28400 | x44.38 |
| `sinh` | 38350 | 29840 | x46.62 |
| `atan2` | 38440 | 29930 | x46.77 |
| `tanh` | 39830 | 31320 | x48.94 |
| `sin_cos` | 40010 | 31500 | x49.22 |

### real_shared_div2

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `alt_per_element_div` | 16040 | 7130 | x1.00 |
| `prepared` | 16170 | 7260 | x1.02 |

### real_shared_div3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `prepared` | 19620 | 10710 | x1.00 |
| `alt_per_element_div` | 19970 | 11060 | x1.03 |

### real_shared_div4

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `prepared` | 24140 | 14430 | x1.00 |
| `alt_per_element_div` | 24970 | 15260 | x1.06 |

### real_sinh_cosh

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 50110 | 42000 | x1.00 |
| `generic` | 50110 | 42000 | x1.00 |

### real_sum_prod2

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 11090 | 1780 | x1.00 |
| `named` | 11090 | 1780 | x1.00 |

### real_sum_prod3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 11290 | 1980 | x1.00 |
| `named` | 11290 | 1980 | x1.00 |

### real_sum_prod4

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 11490 | 2180 | x1.00 |
| `named` | 11490 | 2180 | x1.00 |

### real_trunc

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 10490 | 2380 | x1.00 |
| `generic` | 10490 | 2380 | x1.00 |

