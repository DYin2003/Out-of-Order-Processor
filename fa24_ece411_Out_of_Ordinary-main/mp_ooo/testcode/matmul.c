
int funct(int a) {

    return a+4;
}
int main(){
    int a[3][3];
    int b[3][3];
    int c[3][3];
    for (int i =0; i <3;i++){
        for (int j=0;j<3;j++){
            a[j][i]=1;
            b[j][i]=2;
            c[j][i]=0;
        }
    }

    for(int i=0;i<3;i++){
        for(int j=0;j<3;j++){
            for(int k=0;k<3;k++){
                c[i][j] += a[i][k] * b[k][j];
            }
        }
    }
    for (int i =0; i < 2;i++) {
        c[i][i] = funct(c[i][i]);
    }
    return 1;

}

