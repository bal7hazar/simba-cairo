# Gas report

Sierra gas (`l2_gas`) per benchmark; `net` = raw - group baseline.

## simba::benches

### real_cross3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 22480 | 5340 | x1.00 |
| `generic` | 22480 | 5340 | x1.00 |

### real_diff_prod

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 18920 | 1780 | x1.00 |
| `named` | 18920 | 1780 | x1.00 |

### real_dot3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 19120 | 1980 | x1.00 |
| `generic` | 19120 | 1980 | x1.00 |

### real_jacobi_c

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `alt_inv_norm2` | 20780 | 4840 | x1.00 |
| `recip_sqrt` | 22690 | 6750 | x1.39 |

### real_mul_add

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 18920 | 1780 | x1.00 |
| `named` | 18920 | 1780 | x1.00 |

### real_norm16

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 23880 | 6740 | x1.00 |
| `typed` | 23880 | 6740 | x1.00 |

### real_norm3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `direct` | 18560 | 2220 | x1.00 |
| `generic` | 18560 | 2220 | x1.00 |

### real_norm6

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 22080 | 4940 | x1.00 |
| `typed` | 22080 | 4940 | x1.00 |

### real_norm9

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 22480 | 5340 | x1.00 |
| `typed` | 22580 | 5440 | x1.02 |

### real_normalize3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `recip` | 23840 | 7500 | x1.00 |
| `div` | 28020 | 11680 | x1.56 |

### real_scalar

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `add` | 16980 | 640 | x1.00 |
| `mul` | 17920 | 1580 | x2.47 |
| `sqrt` | 18160 | 1820 | x2.84 |
| `recip` | 19160 | 2820 | x4.41 |
| `div` | 19640 | 3300 | x5.16 |
| `inv_norm2` | 20680 | 4340 | x6.78 |
| `cosh` | 44740 | 28400 | x44.38 |
| `sinh` | 46180 | 29840 | x46.62 |
| `atan2` | 46270 | 29930 | x46.77 |
| `tanh` | 47660 | 31320 | x48.94 |
| `sin_cos` | 47840 | 31500 | x49.22 |

### real_shared_div2

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `alt_per_element_div` | 23870 | 7130 | x1.00 |
| `prepared` | 24000 | 7260 | x1.02 |

### real_shared_div3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `prepared` | 27450 | 10710 | x1.00 |
| `alt_per_element_div` | 27800 | 11060 | x1.03 |

### real_shared_div4

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `prepared` | 31970 | 14430 | x1.00 |
| `alt_per_element_div` | 32800 | 15260 | x1.06 |

### real_sum_prod2

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 18920 | 1780 | x1.00 |
| `named` | 18920 | 1780 | x1.00 |

### real_sum_prod3

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 19120 | 1980 | x1.00 |
| `named` | 19120 | 1980 | x1.00 |

### real_sum_prod4

| variant | raw | net | vs best |
|---|---:|---:|---:|
| `acc` | 19320 | 2180 | x1.00 |
| `named` | 19320 | 2180 | x1.00 |

