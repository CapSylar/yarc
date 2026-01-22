package video_pkg;

localparam bit [1:0] VIDEO_CONFIG = 0;
localparam bit [1:0] VIDEO_ADDR = 1;
localparam bit [1:0] VIDEO_STATUS = 2;

typedef struct packed {
    logic is_text_mode; // 1 -> text_mode, 0 -> raw framebuffer mode
    logic is_enabled; // video core enable
} video_config_t;

typedef struct packed {
    logic [31:0] fb_address;
} video_addr_t;

typedef struct packed {
    logic is_vblank;
} video_status_t;

endpackage: video_pkg
