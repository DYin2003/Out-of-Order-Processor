#define I_LOOP  10
#define J_LOOP  10
#define K_LOOP  100

int main(){
    volatile int a, b, c;

    for (int i = 0; i < I_LOOP; i++){
        for (int j = 0; j < J_LOOP; j++){
            for (int k = 0; k < K_LOOP; k++){
                if (i < k)
                    a = i * j + k;
                
                if (i > k)
                    b = i + j + k;
                else
                    b = i - j + k;
                
                if (i == j)
                    c = i / j + k;
                else if ((i%2) == (j%2))
                    c = k * j - i;
                else
                    c = a + b;

            }

        }
    }

    asm volatile ("slti x0, x0, 4");
    asm volatile ("slti x0, x0, 2");
    return 0;
}