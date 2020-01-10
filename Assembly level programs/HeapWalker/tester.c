#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include "assign6.h"

int main(int argc, char **argv) {
   int i, j;
   heap_stats stats;
   void *p[100];
   //void *p[2];
   unsigned char *heap_base;
   setvbuf(stdin, NULL, _IONBF, 0);
   setvbuf(stdout, NULL, _IONBF, 0);
   setvbuf(stderr, NULL, _IONBF, 0);
   srand(time(NULL));

/*
   p[0] = malloc(2000);
   p[1] = malloc(2000);
   p[2] = malloc(2000);

   heap_base = (unsigned char*)(~0xfff & (uint64_t)p[0]);

   free(p[1]);
   p[1] = NULL;
*/

   
   for (i = 0; i < 100; i++) {
      p[i] = malloc(10 + rand() % 1500);
   }
   heap_base = (unsigned char*)(~0xfff & (uint64_t)p[0]);

   j = 15 + rand() % 50; 
   for (i = 0; i < j; i++) {
      int n = rand() % 100;
      if (p[n]) {
         free(p[n]);
         p[n] = NULL;
      }
   }


   heap_walk(heap_base, &stats);

   //printf("Num free blocks: %d\n",heap_stats.num_free_blocks);

}