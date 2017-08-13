#include <stdio.h>
#include <stdlib.h>
#include <time.h>

//CUDA RunTime API
#include <cuda_runtime.h>

//1M
#define DATA_SIZE 1048576

#define THREAD_NUM 1024
#define BLOCK_NUM 32
int data[DATA_SIZE];

//产生大量0-9之间的随机数
void GenerateNumbers(int *number, int size)
{
    for (int i = 0; i < size; i++) {
        number[i] = rand() % 10;
    }
}

//打印设备信息
void printDeviceProp(const cudaDeviceProp &prop)
{
    printf("---------------------------------------------------- \n");
    printf("Device Name : %s \n", prop.name);
    printf("totalGlobalMem : %zu MB\n",prop.totalGlobalMem/(1<<20));
    printf("sharedMemPerBlock : %zu B \n", prop.sharedMemPerBlock);
    printf("regsPerBlock : %d \n", prop.regsPerBlock);
    printf("warpSize : %d \n", prop.warpSize);
    printf("memPitch : %zu B \n", prop.memPitch);
    printf("maxThreadsPerBlock : %d \n", prop.maxThreadsPerBlock);
    printf("maxThreadsDim[0 - 2] : %d %d %d \n", prop.maxThreadsDim[0], prop.maxThreadsDim[1], prop.maxThreadsDim[2]);
    printf("maxGridSize[0 - 2] : %d %d %d \n", prop.maxGridSize[0], prop.maxGridSize[1], prop.maxGridSize[2]);
    printf("totalConstMem : %zu B \n", prop.totalConstMem);
    printf("major.minor : %d.%d \n", prop.major, prop.minor);
    printf("clockRate : %d khz \n", prop.clockRate);
    printf("textureAlignment : %zu B \n", prop.textureAlignment);
    printf("deviceOverlap : %d \n", prop.deviceOverlap);
    printf("multiProcessorCount : %d \n", prop.multiProcessorCount);
    printf("---------------------------------------------------- \n");
}

//CUDA 初始化
bool InitCUDA()
{
    int count;

    //取得支持Cuda的装置的数目
    cudaGetDeviceCount(&count);

    if (count == 0) {
        fprintf(stderr, "There is no device.\n");
        return false;
    }

    int i;

    for (i = 0; i < count; i++) {

        cudaDeviceProp prop;
        cudaGetDeviceProperties(&prop, i);
        //打印设备信息
        printDeviceProp(prop);

        if (cudaGetDeviceProperties(&prop, i) == cudaSuccess) {
            if (prop.major >= 1) {
                break;
            }
        }
    }

    if (i == count) {
        fprintf(stderr, "There is no device supporting CUDA 1.x.\n");
        return false;
    }

    cudaSetDevice(1);

    return true;
}


// __global__ 函数 (GPU上执行) 计算立方和
__global__ static void sumOfSquares(int *num, int* result, clock_t* time)
{

    //表示目前的 thread 是第几个 thread（由 0 开始计算）
    const int tid = threadIdx.x;

    int sum = 0;

    int i;

    //记录运算开始的时间
    clock_t start;

    //只在 thread 0（即 threadIdx.x = 0 的时候）进行记录
    if (tid == 0) start = clock();

    for (i = tid; i < DATA_SIZE; i += THREAD_NUM) {

        sum += num[i] * num[i] * num[i];

    }

    result[tid] = sum;

    //计算时间的动作，只在 thread 0（即 threadIdx.x = 0 的时候）进行
    if (tid == 0) *time = clock() - start;

}





int main()
{

    //CUDA 初始化
    if (!InitCUDA()) {
        return 0;
    }

    //生成随机数
    GenerateNumbers(data, DATA_SIZE);

    /*把数据复制到显卡内存中*/
    int* gpudata, *result;

    clock_t* time;

    //cudaMalloc 取得一块显卡内存 ( 其中result用来存储计算结果，time用来存储运行时间 )
    cudaMalloc((void**)&gpudata, sizeof(int)* DATA_SIZE);
    cudaMalloc((void**)&result, sizeof(int)*THREAD_NUM);
    cudaMalloc((void**)&time, sizeof(clock_t));

    //cudaMemcpy 将产生的随机数复制到显卡内存中
    //cudaMemcpyHostToDevice - 从内存复制到显卡内存
    //cudaMemcpyDeviceToHost - 从显卡内存复制到内存
    cudaMemcpy(gpudata, data, sizeof(int)* DATA_SIZE, cudaMemcpyHostToDevice);

    // 在CUDA 中执行函数 语法：函数名称<<<block 数目, thread 数目, shared memory 大小>>>(参数...);
    sumOfSquares << < 1, THREAD_NUM, 0 >> >(gpudata, result, time);


    /*把结果从显示芯片复制回主内存*/

    int sum[THREAD_NUM];

    clock_t time_use;

    //cudaMemcpy 将结果从显存中复制回内存
    cudaMemcpy(&sum, result, sizeof(int)* THREAD_NUM, cudaMemcpyDeviceToHost);
    cudaMemcpy(&time_use, time, sizeof(clock_t), cudaMemcpyDeviceToHost);

    //Free
    cudaFree(gpudata);
    cudaFree(result);
    cudaFree(time);

    int final_sum = 0;

    for (int i = 0; i < THREAD_NUM; i++) {

        final_sum += sum[i];

    }

    printf("GPUsum: %d  gputime: %d\n", final_sum, time_use);

    final_sum = 0;

    for (int i = 0; i < DATA_SIZE; i++) {

        final_sum += data[i] * data[i] * data[i];

    }

    printf("CPUsum: %d \n", final_sum);

    return 0;
}