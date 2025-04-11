#define INPUT_SIZE    256
#define KERNEL_SIZE   9
#define CONV_OUTPUT   26
#define POOL_SIZE     2
#define POOL_OUTPUT   13
#define NUM_FILTERS   4

int main() {
    volatile int input[INPUT_SIZE][INPUT_SIZE];
    volatile int kernel[NUM_FILTERS][KERNEL_SIZE][KERNEL_SIZE];
    volatile int conv_output[NUM_FILTERS][CONV_OUTPUT][CONV_OUTPUT];
    volatile int pool_output[NUM_FILTERS][POOL_OUTPUT][POOL_OUTPUT];
    volatile int temp_sum, max_val;

    // Initialize input with dummy data
    for (int i = 0; i < INPUT_SIZE; i++) {
        for (int j = 0; j < INPUT_SIZE; j++) {
            input[i][j] = (i + j) % 255;
        }
    }

    // Initialize kernels with dummy weights
    for (int f = 0; f < NUM_FILTERS; f++) {
        for (int i = 0; i < KERNEL_SIZE; i++) {
            for (int j = 0; j < KERNEL_SIZE; j++) {
                kernel[f][i][j] = (i * j + f) % 9 - 4;
            }
        }
    }

    // Convolution Layer
    for (int f = 0; f < NUM_FILTERS; f++) {
        for (int i = 0; i < CONV_OUTPUT; i++) {
            for (int j = 0; j < CONV_OUTPUT; j++) {
                temp_sum = 0;
                
                for (int ki = 0; ki < KERNEL_SIZE; ki++) {
                    for (int kj = 0; kj < KERNEL_SIZE; kj++) {
                        temp_sum += input[i + ki][j + kj] * kernel[f][ki][kj];
                    }
                }

                // ReLU activation
                if (temp_sum < 0)
                    conv_output[f][i][j] = 0;
                else
                    conv_output[f][i][j] = temp_sum;
            }
        }
    }

    // Max Pooling Layer
    for (int f = 0; f < NUM_FILTERS; f++) {
        for (int i = 0; i < POOL_OUTPUT; i++) {
            for (int j = 0; j < POOL_OUTPUT; j++) {
                max_val = conv_output[f][i*2][j*2];
                
                if (conv_output[f][i*2][j*2 + 1] > max_val)
                    max_val = conv_output[f][i*2][j*2 + 1];
                
                if (conv_output[f][i*2 + 1][j*2] > max_val)
                    max_val = conv_output[f][i*2 + 1][j*2];
                
                if (conv_output[f][i*2 + 1][j*2 + 1] > max_val)
                    max_val = conv_output[f][i*2 + 1][j*2 + 1];
                
                pool_output[f][i][j] = max_val;
            }
        }
    }

    asm volatile ("slti x0, x0, 4");
    asm volatile ("slti x0, x0, 2");
    return 0;
}