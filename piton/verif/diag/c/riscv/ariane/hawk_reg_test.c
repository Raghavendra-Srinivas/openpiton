

//HAWK TEST

#include <stdio.h>

#define HAWK_REG_BASE  0xfff5100000ULL
#define LOW_WATERMARK  0x4

//For Interrupt Testing
//PLIC - Not needed
#define PLIC_BASE    0xfff1100000ULL

#define IRQ_ENABLE_TARGET1 0x0002000 //Per IrQ 1 bit from lsb = 'b100 for hawk
#define IRQ_ENABLE_TARGET2 0x0002080 //

#define IRQ_PRIORITY_SRC0 0x0000000
#define IRQ_PRIORITY_SRC1 0x0000004
#define IRQ_PRIORITY_SRC2 0x0000008 //for hawk -set it to 3'b111
#define IRQ_PRIORITY_SRC3 0x000000C //for hawk -set it to 3'b111
//


int main(int argc, char ** argv) {
  uint64_t *addr;
  volatile uint32_t val;

  printf("\nHello World ..!\n");
  printf("Performing HAWK Test ..\n");
  for (int k = 0; k < 1; k++) {
    // assemble number and print
    printf("Hello world, I am HART %d! Counting (%d of 32)...\n", argv[0][0], k);
  }

  //Assert Interrupt
  addr = (uint64_t*)(HAWK_REG_BASE+LOW_WATERMARK);
  printf("HAWK LOW WATER MARK : Default Value = 0x%016x\n",*addr);
  printf("HAWK LOW WATER MARK : Writing Register with 0x13572468\n");
  *addr = (uint32_t) 0x13572468;
  printf("HAWK LOW WATER MARK : Read back Value = 0x%016x\n",*addr);

/* 
  addr = (uint32_t*)(PLIC_BASE+IRQ_ENABLE_TARGET1);
  val = *addr;
  printf("PLIC TARGET1 IRQ Enable before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0x8;
  *addr=val; 
  printf("PLIC TARGET1 IRQ Enable after 0x%llx, data = 0x%x\n",addr,*addr);

  addr = (uint32_t*)(PLIC_BASE+IRQ_PRIORITY_SRC3);
  val = *addr;
  printf("PLIC PRIORITY SRC3 before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0x7;
  *addr=val; 
  printf("PLIC PRIORITY SRC3 after 0x%llx, data = 0x%x\n",addr,*addr);

  //Assert Interrupt
  addr = (uint64_t*)(HAWK_REG_BASE);
  printf("HACD: Cntrl result = 0x%016x\n",*addr);
  printf("Writing Control Register.\n");
  *addr = (uint32_t) 0x1;
  printf("HACD: Cntrl result = 0x%016x\n",*addr);
 

  addr = (uint32_t*)(PLIC_BASE+IRQ_ENABLE_TARGET2);
  val = *addr;
  printf("PLIC TARGET2 IRQ Enable before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0xF;
  *addr=val; 
  printf("PLIC TARGET2 IRQ Enable after 0x%llx, data = 0x%x\n",addr,*addr);


  addr = (uint32_t*)(PLIC_BASE+IRQ_PRIORITY_SRC0);
  val = *addr;
  printf("PLIC PRIORITY SRC0 before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0x7;
  *addr=val; 
  printf("PLIC PRIORITY SRC0 after 0x%llx, data = 0x%x\n",addr,*addr);

  addr = (uint32_t*)(PLIC_BASE+IRQ_PRIORITY_SRC1);
  val = *addr;
  printf("PLIC PRIORITY SRC1 before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0x7;
  *addr=val; 
  printf("PLIC PRIORITY SRC1 after 0x%llx, data = 0x%x\n",addr,*addr);

  addr = (uint32_t*)(PLIC_BASE+IRQ_PRIORITY_SRC2);
  val = *addr;
  printf("PLIC PRIORITY SRC2 before 0x%llx, data = 0x%x\n",addr,val);
  val = val | 0x7;
  *addr=val; 
  printf("PLIC PRIORITY SRC2 after 0x%llx, data = 0x%x\n",addr,*addr);
 */
    
  printf("HAWK Test Done!..\n");

  return 0;
}

