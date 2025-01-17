#include <cuda.h>
#include <cuda_runtime.h>
#include "common.h"
#include "naive.h"

#define block_size 320

namespace StreamCompaction {
    namespace Naive {
        using StreamCompaction::Common::PerformanceTimer;
        PerformanceTimer& timer()
        {
            static PerformanceTimer timer;
            return timer;
        }
        // TODO: __global__
        __global__ void kern_scan_global(int d, int n, const int* idata, int* odata)
        {
            int index = threadIdx.x + (blockIdx.x * blockDim.x);
            if (index >= n)
            {
				return;
			}
            int offset = (1 << (d - 1));
            if (index >= offset)
            {
                odata[index] = idata[index - offset] + idata[index];
            }
            else
            {
				odata[index] = idata[index];
			}
        }

        __global__ void kern_inclusive_to_exclusive(int n, const int* idata, int* odata)
        {
            int index = threadIdx.x + (blockIdx.x * blockDim.x);
			if (index >= n)
			{ 
                return;
            }
            if (index == 0)
            {
				odata[index] = 0;
			}
            else
            {
				odata[index] = idata[index - 1];
			}
        }


        /**
         * Performs prefix-sum (aka scan) on idata, storing the result into odata.
         */
        void scan(int n, int *odata, const int *idata) {
            int *dev_idata;
            int* dev_odata;
            dim3 full_blocks_per_grid((n + block_size - 1) / block_size);

            cudaMalloc((void**)&dev_idata, n * sizeof(int));
            checkCUDAErrorFn("cudaMalloc dev_idata failed!");
            cudaMalloc((void**)&dev_odata, n * sizeof(int));
            checkCUDAErrorFn("cudaMalloc dev_odata failed!");

            cudaMemcpy(dev_idata, idata, sizeof(int) * n, cudaMemcpyHostToDevice);
            checkCUDAErrorFn("cudaMemcpy dev_idata failed!");

            timer().startGpuTimer();
            
            for (int i = 0; i < ilog2ceil(n); i++)
            {
                kern_scan_global <<<full_blocks_per_grid, block_size>>> (i + 1, n, dev_idata, dev_odata);
				std::swap(dev_idata, dev_odata);
            }
            kern_inclusive_to_exclusive <<<full_blocks_per_grid, block_size>>> (n, dev_idata, dev_odata);

            timer().endGpuTimer();
            cudaMemcpy(odata, dev_odata, sizeof(int) * n, cudaMemcpyDeviceToHost);
            checkCUDAErrorFn("cudaMemcpy dev_odata failed!");

            cudaFree(dev_idata);
            checkCUDAErrorFn("cudaFree dev_idata failed!");
            cudaFree(dev_odata);
            checkCUDAErrorFn("cudaFree dev_odata failed!");

        }

    }
}
