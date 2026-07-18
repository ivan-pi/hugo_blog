import numpy as np

import timeit
import time

x = np.random.rand(32768)

t0 = time.time()
idx = np.where(x == x[-1])
t1 = time.time()
print("np.array: Total time (ns) = ", (t1 - t0)*1e9)

x = list(x)

t0 = time.time()
idx = x.index(x[-1])
t1 = time.time()

print("list: Total time (ns) = ", (t1 - t0)*1e9)
