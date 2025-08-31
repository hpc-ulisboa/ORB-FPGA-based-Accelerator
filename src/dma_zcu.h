#ifndef DMA_H
#define DMA_H
#endif

#include <cerrno>
#include <clocale>
#include <cstring>
#include <errno.h>
#include <fcntl.h>
#include <iostream>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

// #define DMA_BASE_ADDR 0x40000000           // 0xA0030000
// #define DMA_ADDR_HIGH 0x40000FFF           // 0xA003FFFF
#define INPUT_BUFFER_BASE_ADDR 0x20010000  // 0x70000000 Escolhi eu
#define INPUT_BUFFER_ADDR_HIGH 0x2001FFFF  // 0x70007FFF Escolhi eu
#define OUTPUT_BUFFER_BASE_ADDR 0x30010000 // 0x70008000 Escolhi eu
#define OUTPUT_BUFFER_ADDR_HIGH 0x3001FFFF // 0x7000FFFF Escolhi eu

#define BRAM_BASE_ADDR 0x42000000 // 0xA0000000
#define BRAM_ADDR_HIGH 0x4200FFFF // 0xA0003FFF
// #define BRAM_FEAT_BASE_ADDR 0x44000000 // 0xA0030000
// #define BRAM_FEAT_ADDR_HIGH 0x44001FFF // 0xA003FFFF
#define BRAM_DESCRIPT0_BASE_ADDR 0x46000000
#define BRAM_DESCRIPT0_ADDR_HIGH 0x46001FFF
#define BRAM_DESCRIPT1_BASE_ADDR 0x44000000
#define BRAM_DESCRIPT1_ADDR_HIGH 0x44001FFF
//#define BRAM_DESCRIPT2_BASE_ADDR 0x4A000000
//#define BRAM_DESCRIPT2_ADDR_HIGH 0x4A007FFF
//#define BRAM_DESCRIPT3_BASE_ADDR 0x4C000000
//#define BRAM_DESCRIPT3_ADDR_HIGH 0x4C007FFF
//#define BRAM_DESCRIPT4_BASE_ADDR 0x50000000
//#define BRAM_DESCRIPT4_ADDR_HIGH 0x50007FFF
//#define BRAM_DESCRIPT5_BASE_ADDR 0x52000000
//#define BRAM_DESCRIPT5_ADDR_HIGH 0x52007FFF
//#define BRAM_DESCRIPT6_BASE_ADDR 0x54000000
//#define BRAM_DESCRIPT6_ADDR_HIGH 0x54007FFF
//#define BRAM_DESCRIPT7_BASE_ADDR 0x56000000
//#define BRAM_DESCRIPT7_ADDR_HIGH 0x56007FFF
#define BRAM_DESCRIPT_POS_BASE_ADDR 0x48000000
#define BRAM_DESCRIPT_POS_ADDR_HIGH 0x48001FFF
#define BRAM_DESCRIPT_SCR_ANGLE_BASE_ADDR 0x40000000
#define BRAM_DESCRIPT_SCR_ANGLE_ADDR_HIGH 0x40007FFF
#define RESET_BASE_ADDR 0x41220000 // 0xA0030000
#define RESET_ADDR_HIGH 0x4122FFFF // 0xA003FFFF
#define CORNER_THRESH_BASE_ADDR 0x41230000
#define CORNER_THRESH_ADDR_HIGH 0x4123FFFF
//#define RGB_RG_BASE_ADDR 0x41210000
//#define RGB_RG_ADDR_HIGH 0x4121FFFF
//#define RGB_B_BASE_ADDR 0x41200000
//#define RGB_B_ADDR_HIGH 0x4120FFFF

#define DMA_NOP 0x00000000
#define DMA_DRAM_TO_FPGA 0x40000000
#define DMA_FPGA_TO_DRAM 0x80000000
#define DMA_DUAL_MODE 0xC0000000

typedef struct {
  uint32_t opcode;
} dma_instr_r0_t;

typedef struct {
  uint32_t ib_addr;
} dma_instr_r2_t;

typedef struct {
  uint32_t pl_addr;
} dma_instr_r3_t;

typedef struct {
  uint32_t ob_addr;
} dma_instr_r4_t;

typedef struct {
  dma_instr_r4_t _r4;
  dma_instr_r3_t _r3;
  dma_instr_r2_t _r2;
  dma_instr_r0_t _r0;
} dma_instr_t;

typedef struct {
  int fd;
  int dma_fd;
  int ib_fd;
  int ob_fd;
  // int feat_fd;
  int descriptors0_fd;
  int descriptors1_fd;
  //int descriptors2_fd;
  //int descriptors3_fd;
  //int descriptors4_fd;
  //int descriptors5_fd;
  //int descriptors6_fd;
  //int descriptors7_fd;
  int descriptors_pos_fd;
  int descriptors_scr_angle_fd;
  int reset_fd;
  int corner_thresh_fd;
  int rgb_rg_fd;
  int rgb_b_fd;
} platform_t;

typedef uint32_t u32;
typedef uint64_t u64;
typedef u32 cmd_t;

volatile u32 *_dma_ptr;
volatile u64 *_in_buffer;
int _ib_pointer;
volatile u64 *_out_buffer;
int _ob_pointer;
volatile u64 *_bram_ptr;
// volatile u64 *_features_ptr;
volatile u32 *_descripts_ptr[2];
volatile u32 *_descripts_pos_ptr;
volatile u32 *_descripts_scr_angle_ptr;
volatile u64 *_corner_thresh_ptr;
volatile u64 *_rgb_rg_ptr;
volatile u64 *_rgb_b_ptr;
volatile u64 *_reset_ptr;

char *dma_string[4] = {"NOP", "DRAM>>PL", "PL>>DRAM", "DRAM>>PL>>DRAM"};

extern int errno;

#define RETURN_SIZE(x) x / 4 + ((x % 4) != 0)

#define DEBUG_DMA 0

/* int init_dma() {
  unsigned int dma_size = DMA_ADDR_HIGH + 1 - DMA_BASE_ADDR;
  off_t dma_pbase = DMA_BASE_ADDR; // physical base address
  int fd;

  //printf("Initializing PTA DMA...\n");
  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) != -1) {

    _dma_ptr = (u32 *)mmap(NULL, dma_size, PROT_READ | PROT_WRITE, MAP_SHARED,
                           fd, dma_pbase);

    if (_dma_ptr == MAP_FAILED) {
      close(fd);
      //printf("ERROR: Can't map memory, _dma_ptr\n");
      return -1;
    }

    //printf("Success!\n");
  } else {
    //printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
} */

int init_ibuffer() {
  unsigned int ibuffer_size =
      INPUT_BUFFER_ADDR_HIGH + 1 - INPUT_BUFFER_BASE_ADDR;
  off_t ibuffer_pbase = INPUT_BUFFER_BASE_ADDR; // physical base address
  int fd;

  //printf("Initializing INPUT BUFFER...\n");
  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) != -1) {

    _in_buffer = (u64 *)mmap(NULL, ibuffer_size, PROT_READ | PROT_WRITE,
                             MAP_SHARED, fd, ibuffer_pbase);
    _ib_pointer = 0;

    if (_in_buffer == MAP_FAILED) {
      close(fd);
      //printf("ERROR: Can't map memory, _in_buffer\n");
      return -1;
    }

    //printf("Success!\n");
  } else {
    //printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
}

int init_obuffer() {
  unsigned int obuffer_size =
      OUTPUT_BUFFER_ADDR_HIGH + 1 - OUTPUT_BUFFER_BASE_ADDR;
  off_t obuffer_pbase = OUTPUT_BUFFER_BASE_ADDR; // physical base address
  int fd;

  //printf("Initializing OUTPUT BUFFER...\n");
  if ((fd = open("/dev/mem", O_RDWR)) != -1) {
    _out_buffer = (u64 *)mmap(NULL, obuffer_size, PROT_READ | PROT_WRITE,
                              MAP_SHARED, fd, obuffer_pbase);
    _ob_pointer = 0;

    if (_out_buffer == MAP_FAILED) {
      //printf("%d", errno);
      switch (errno) {
      case EACCES:
        //printf("\n\nEACCES\n\n");
        break;
      case EBADF:
        //printf("\n\nEBADF\n\n");
        break;
      case EINVAL:
        //printf("\n\nEINVAL\n\n");
        break;
      case ENODEV:
        //printf("\n\nENODEV\n\n");
        break;
      case ENXIO:
        //printf("\n\nENXIO\n\n");
        break;
      case EOVERFLOW:
        //printf("\n\nEOVERFLOW\n\n");
        break;
      }
      close(fd);
      //printf("ERROR: Can't map memory, _out_buffer\n");
      return -1;
    }

    //printf("Success!\n");
  } else {
    //printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
}

int init_test_bram() {
  unsigned int bram_size = BRAM_ADDR_HIGH + 1 - BRAM_BASE_ADDR;
  off_t bram_pbase = BRAM_BASE_ADDR; // physical base address
  int fd;

  //printf("Initializing TEST BRAM...\n");
  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) != -1) {

    _bram_ptr = (u64 *)mmap(NULL, bram_size, PROT_READ | PROT_WRITE, MAP_SHARED,
                            fd, bram_pbase);

    if (_bram_ptr == MAP_FAILED) {
      close(fd);
      //printf("ERROR: Can't map memory, _bram_ptr\n");
      return -1;
    }

    //printf("Success!\n");
  } else {
    //printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
}

/* int init_features_bram() {
  unsigned int features_size = BRAM_FEAT_ADDR_HIGH + 1 - BRAM_FEAT_BASE_ADDR;
  off_t features_pbase = BRAM_FEAT_BASE_ADDR; // physical base address
  int fd;

  //printf("Initializing Features BRAM...\n");
  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) != -1) {

    _features_ptr = (u64 *)mmap(NULL, features_size, PROT_READ | PROT_WRITE,
                                MAP_SHARED, fd, features_pbase);
    // std::cout << std::strerror(errno);
    if (_features_ptr == MAP_FAILED) {
      close(fd);
      perror("mmap(_features_ptr)");
      std::cout << errno << std::endl;
      return -1;
    }

    //printf("Success!\n");
  } else {
    //printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
} */

int init_descriptors_bram(unsigned int addr_high, unsigned int base_addr,
                          unsigned int index) {
  unsigned int descript_size = addr_high + 1 - base_addr;
  off_t descript_pbase = base_addr; // physical base address
  int fd;

  //printf("Initializing Descriptor[%d] BRAMs...\n", index);

  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) != -1) {

    _descripts_ptr[index] =
        (u32 *)mmap(NULL, descript_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd,
                    descript_pbase);
    // std::cout << std::strerror(errno);
    if (_descripts_ptr[index] == MAP_FAILED) {
      close(fd);
      perror("mmap(_descripts_ptr)");
      std::cout << errno << std::endl;
      return -1;
    }

   //printf("Success!\n");
  } else {
    printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
}

int init_descriptors_pos_bram() {
  unsigned int descript_size =
      BRAM_DESCRIPT_POS_ADDR_HIGH + 1 - BRAM_DESCRIPT_POS_BASE_ADDR;
  off_t descript_pbase = BRAM_DESCRIPT_POS_BASE_ADDR; // physical base address
  int fd;

  //printf("Initializing Descriptor Position BRAMs...\n");
  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) != -1) {

    _descripts_pos_ptr =
        (u32 *)mmap(NULL, descript_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd,
                    descript_pbase);
    // std::cout << std::strerror(errno);
    if (_descripts_pos_ptr == MAP_FAILED) {
      close(fd);
      perror("mmap(_descripts_pos_ptr)");
      std::cout << errno << std::endl;
      return -1;
    }

    //printf("Success!\n");
  } else {
    //printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
}

int init_descriptors_scr_angle_bram() {
  unsigned int descript_size =
      BRAM_DESCRIPT_SCR_ANGLE_ADDR_HIGH + 1 - BRAM_DESCRIPT_SCR_ANGLE_BASE_ADDR;
  off_t descript_pbase =
      BRAM_DESCRIPT_SCR_ANGLE_BASE_ADDR; // physical base address
  int fd;

  //printf("Initializing Descriptor Score Angle BRAMs...\n");
  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) != -1) {

    _descripts_scr_angle_ptr =
        (u32 *)mmap(NULL, descript_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd,
                    descript_pbase);
    // std::cout << std::strerror(errno);
    if (_descripts_scr_angle_ptr == MAP_FAILED) {
      close(fd);
      perror("mmap(_descripts_scr_angle_ptr)");
      std::cout << errno << std::endl;
      return -1;
    }

    //printf("Success!\n");
  } else {
    //printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
}

int init_reset_gpio() {
  unsigned int reset_size = RESET_ADDR_HIGH + 1 - RESET_BASE_ADDR;
  off_t reset_pbase = RESET_BASE_ADDR; // physical base address
  int fd;

  //printf("Initializing Reset GPIO...\n");
  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) != -1) {

    _reset_ptr = (u64 *)mmap(NULL, reset_size, PROT_READ | PROT_WRITE,
                             MAP_SHARED, fd, reset_pbase);
    // std::cout << std::strerror(errno);
    if (_reset_ptr == MAP_FAILED) {
      close(fd);
      perror("mmap(_reset_ptr)");
      std::cout << errno << std::endl;
      return -1;
    }

    //printf("Success!\n");
  } else {
    //printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
}

/* int init_rgb_b_gpio() {
  unsigned int rgb_b_size = RGB_B_ADDR_HIGH + 1 - RGB_B_BASE_ADDR;
  off_t rgb_b_pbase = RGB_B_BASE_ADDR; // physical base address
  int fd;

  //printf("Initializing RGB B GPIO...\n");
  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) != -1) {

    _rgb_b_ptr = (u64 *)mmap(NULL, rgb_b_size, PROT_READ | PROT_WRITE,
                             MAP_SHARED, fd, rgb_b_pbase);
    // std::cout << std::strerror(errno);
    if (_rgb_b_ptr == MAP_FAILED) {
      close(fd);
      perror("mmap(_rgb_b_ptr)");
      std::cout << errno << std::endl;
      return -1;
    }

    //printf("Success!\n");
  } else {
    //printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
}

int init_rgb_rg_gpio() {
  unsigned int rgb_rg_size = RGB_RG_ADDR_HIGH + 1 - RGB_RG_BASE_ADDR;
  off_t rgb_rg_pbase = RGB_RG_BASE_ADDR; // physical base address
  int fd;

  //printf("Initializing RGB RG GPIO...\n");
  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) != -1) {

    _rgb_rg_ptr = (u64 *)mmap(NULL, rgb_rg_size, PROT_READ | PROT_WRITE,
                              MAP_SHARED, fd, rgb_rg_pbase);
    // std::cout << std::strerror(errno);
    if (_rgb_rg_ptr == MAP_FAILED) {
      close(fd);
      perror("mmap(_rgb_rg_ptr)");
      std::cout << errno << std::endl;
      return -1;
    }

    //printf("Success!\n");
  } else {
    //printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
} */

int init_corner_thresh_gpio() {
  unsigned int corner_thresh_size =
      CORNER_THRESH_ADDR_HIGH + 1 - CORNER_THRESH_BASE_ADDR;
  off_t corner_thresh_pbase = CORNER_THRESH_BASE_ADDR; // physical base address
  int fd;

  //printf("Initializing Corner threshold GPIO...\n");
  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) != -1) {

    _corner_thresh_ptr =
        (u64 *)mmap(NULL, corner_thresh_size, PROT_READ | PROT_WRITE,
                    MAP_SHARED, fd, corner_thresh_pbase);
    // std::cout << std::strerror(errno);
    if (_corner_thresh_ptr == MAP_FAILED) {
      close(fd);
      perror("mmap(_corner_thresh_ptr)");
      std::cout << errno << std::endl;
      return -1;
    }

    //printf("Success!\n");
  } else {
    //printf("ERROR: Could not open device %d\n", fd);
  }

  return fd;
}

platform_t init_platform() {
  platform_t p;
  //printf("PTA initialization started...\n");
  p.fd = init_test_bram();
  // p.dma_fd = init_dma();
  p.ib_fd = init_ibuffer();
  p.ob_fd = init_obuffer();
  // p.feat_fd = init_features_bram();
  p.descriptors0_fd = init_descriptors_bram(BRAM_DESCRIPT0_ADDR_HIGH,
                                            BRAM_DESCRIPT0_BASE_ADDR, 0);
  p.descriptors1_fd = init_descriptors_bram(BRAM_DESCRIPT1_ADDR_HIGH,
                                            BRAM_DESCRIPT1_BASE_ADDR, 1);
  //p.descriptors2_fd = init_descriptors_bram(BRAM_DESCRIPT2_ADDR_HIGH,
  //                                          BRAM_DESCRIPT2_BASE_ADDR, 2);
  //p.descriptors3_fd = init_descriptors_bram(BRAM_DESCRIPT3_ADDR_HIGH,
  //                                          BRAM_DESCRIPT3_BASE_ADDR, 3);
  //p.descriptors4_fd = init_descriptors_bram(BRAM_DESCRIPT4_ADDR_HIGH,
  //                                          BRAM_DESCRIPT4_BASE_ADDR, 4);
  //p.descriptors5_fd = init_descriptors_bram(BRAM_DESCRIPT5_ADDR_HIGH,
  //                                          BRAM_DESCRIPT5_BASE_ADDR, 5);
  //p.descriptors6_fd = init_descriptors_bram(BRAM_DESCRIPT6_ADDR_HIGH,
  //                                          BRAM_DESCRIPT6_BASE_ADDR, 6);
  //p.descriptors7_fd = init_descriptors_bram(BRAM_DESCRIPT7_ADDR_HIGH,
  //                                          BRAM_DESCRIPT7_BASE_ADDR, 7);
  p.descriptors_pos_fd = init_descriptors_pos_bram();
  p.descriptors_scr_angle_fd = init_descriptors_scr_angle_bram();
  p.reset_fd = init_reset_gpio();
  //p.rgb_b_fd = init_rgb_b_gpio();
  //p.rgb_rg_fd = init_rgb_rg_gpio();
  p.corner_thresh_fd = init_corner_thresh_gpio();
 //printf("PTA initialization done!\n\n");

  return p;
}

void close_platform(platform_t p) {
  //printf("Closing platform...\n");
  close(p.fd);
  close(p.dma_fd);
  close(p.ib_fd);
  close(p.ob_fd);
  // close(p.feat_fd);
  close(p.descriptors0_fd);
  close(p.descriptors1_fd);
  //close(p.descriptors2_fd);
  //close(p.descriptors3_fd);
  //close(p.descriptors4_fd);
  //close(p.descriptors5_fd);
  //close(p.descriptors6_fd);
  //close(p.descriptors7_fd);
  close(p.descriptors_pos_fd);
  close(p.descriptors_scr_angle_fd);
  close(p.reset_fd);
  //close(p.rgb_b_fd);
  //close(p.rgb_rg_fd);
  close(p.corner_thresh_fd);
  //printf("Done!\n");
}

void dma_create_tx(dma_instr_t *instr, cmd_t direction, cmd_t ib_addr,
                   cmd_t pl_addr, cmd_t ob_addr, cmd_t size_pl, cmd_t size_ps) {

  if (direction != DMA_NOP && direction != DMA_DRAM_TO_FPGA &&
      direction != DMA_FPGA_TO_DRAM && direction != DMA_DUAL_MODE) {
    //printf("WARNING: Wrong DMA direction.\n\r");
    return;
  }
  if (size_pl > 255) {
    //printf("WARNING: DMA-PL supports burst sizes < 256 beats.\n");
    return;
  }
  if (size_ps > 255) {
    //printf("WARNING: DMA-PS supports burst sizes < 256 beats.\n");
    return;
  }

  instr->_r4.ob_addr = ob_addr;
  instr->_r3.pl_addr = pl_addr;
  instr->_r2.ib_addr = ib_addr;
  instr->_r0.opcode = direction | ((size_pl - 1) << 8) | (size_ps - 1);

  //if (DEBUG_DMA)
    /*printf("\t(DMA_CMD::CREATE) %s SIZE_PL:%i SIZE_PS:%i (OPCODE:0x%X IB:0x%X  "
           "PL:0x%X  OB:0x%X)\n",
           dma_string[direction >> 30], size_pl, size_ps, instr->_r0.opcode,
           ib_addr, pl_addr, ob_addr);*/
}

void dma_run(dma_instr_t instr) {
  _dma_ptr[4] = *(u32 *)&(instr._r4);
  _dma_ptr[3] = *(u32 *)&(instr._r3);
  _dma_ptr[2] = *(u32 *)&(instr._r2);
  _dma_ptr[0] = *(u32 *)&(instr._r0);

  //if (DEBUG_DMA)
    /*printf("\t(DMA_CTRL::START) %s SIZE_PL:%i SIZE_PS:%i (OPCODE:0x%X IB:0x%X  "
           "PL:0x%X  OB:0x%X)\n",
           dma_string[instr._r0.opcode >> 30],
           ((instr._r0.opcode & 0x0000FF00) >> 8),
           (instr._r0.opcode & 0x000000FF), instr._r0.opcode, instr._r2.ib_addr,
           instr._r3.pl_addr, instr._r4.ob_addr);*/

  u32 r;
  while ((r = _dma_ptr[1]) == 0) {
  };

  //if (DEBUG_DMA)
    //printf("\t(DMA_CTRL::DONE) STATUS:0x%lX\n", r);
}

void dma_ib_reset() { _ib_pointer = 0; }

int dma_ib_get() { return _ib_pointer; }

void dma_ib_set(int val) { _ib_pointer = val; }

int dma_ib_next() {
  int r = _ib_pointer;
  _ib_pointer++;
  return r;
}

void dma_ob_reset() { _ob_pointer = 0; }

int dma_ob_get() { return _ob_pointer; }

void dma_ob_set(int val) { _ob_pointer = val; }

int dma_ob_next() {
  int r = _ob_pointer;
  _ob_pointer++;
  return r;
}
