printf = function(s,...)
           return io.write(s:format(...))
         end -- function

cpuflags = cpu.flags()
boardfound = 0
-- NOTE: DMI-token-specific sections may still override this and force a
-- 32-bit install even on 64-bit systems (i.e. on Irwindale Xeons, where
-- 64-bit mode may adversely impact performance).

if (cpuflags["flags.lm"] == "yes") then
  kernfile = "kern64"
  initramfile = "ram64"
else
  kernfile = "kern32"
  initramfile = "ram32"
end

ttyarg = ""

if (dmi.supported()) then
  dmitable = dmi.gettable()

  if (string.upper(string.sub(dmitable["system.manufacturer"], 1, 5)) == "INTEL") then
    -- Intel supplies both the MPCBL0001 (Kennicott) and MPCBL0040 (Damascus)
    -- blade; they sport consistent DMI information, with the caveat that
    -- sometimes Intel will append a suffix to the product name to distinguish
    -- certain feature presence (like integrated fiber-channel on Kennicott).
    -- Both run exclusively off ttyS0 at 9600baud.
    if (string.upper(string.sub(dmitable["system.product_name"], 1, 9)) == "MPCBL0040") then
      boardfound = 1
      printf("Detected Intel MPCBL0040 (Damascus) blade\n")
      ttyarg = "console=ttyS0,9600n8"
    -- NOTE: we have a ton of Kennicott engineering samples in play in our
    -- development labs.  It's possible many of them have incorrect or
    -- incomplete DMI information, in which case this check may not work.
    elseif (string.upper(string.sub(dmitable["system.product_name"], 1, 9)) == "MPCBL0001") then
      boardfound = 1
      printf("Detected Intel MPCBL0001 (Kennicott) blade\n")
      ttyarg = "console=ttyS0,9600n8"
    -- Intel also supplies us with three 2U (Langley or Ballinger) variants:
    -- Prestonia (TIGPR2U), Irwindale (TIGI2U), and Harpertown (TIGH2U).  The
    -- Prestonia and Irwindale variants only have the product name populated
    -- in the DMI baseboard information (and it's really just the motherboard
    -- model number, not a chassis model number).
    -- TODO: make sure the Ballinger Harpertowns match, as we switched between
    -- Langley and Ballinger for this particular variant.  Also make sure the
    -- terminal settings are correct/usable between both direct-serial and
    -- serial-over-LAN cases.
    elseif (string.upper(string.sub(dmitable["system.product_name"], 1, 8)) == "T5000PAL") then
      -- This is most likely a TIGH2U (Langley/Ballinger Harpertown).  SOL is
      -- supported, even though Intel kind of shanked it on this product.
      boardfound = 1
      printf("Detected Intel TIGH2U (Langley-Harpertown) system\n")
      ttyarg = "console=tty0 console=ttyS1,19200n8"
    elseif (string.upper(string.sub(dmitable["base_board.product_name"], 1, 10)) == "SE7501WV2S") then
      -- This is most likely a TIGPR2U (Langley Prestonia).  I don't think we
      -- ever supported SOL on this thing.
      boardfound = 1
      printf("Detected Intel TIGPR2U (Langley-Prestonia) system\n")
      ttyarg = "console=tty0 console=ttyS0,19200n8"
    elseif (string.upper(string.sub(dmitable["base_board.product_name"], 1, 11)) == "SE7520JR23S") then
      -- This is most likely a TIGI2U (Langley Irwindale).  Did we ever support
      -- SOL here?  I honestly don't know.
      -- TODO: determine if we want to force Irwindales to 32-bit mode for
      -- performance reasons.
      boardfound = 1
      printf("Detected Intel TIGI2U (Langley-Irwindale) system\n")
      ttyarg = "console=tty0 console=ttyS1,19200n8"
    end
	elseif (string.upper(string.sub(dmitable["system.manufacturer"], 1, 7)) == "RADISYS") and (string.upper(string.sub(dmitable["system.product_name"], 1, 9)) == "MPCBL0040") then
    -- Radisys also supplies the MPCBL0040 (Damascus)
    -- blade; they sport consistent DMI information, with the caveat that
    -- sometimes Intel will append a suffix to the product name to distinguish
    -- certain feature presence (like integrated fiber-channel on Kennicott).
    -- Both run exclusively off ttyS0 at 9600baud.
      boardfound = 1
      printf("Detected RadiSys MPCBL0040 (Damascus) blade\n")
      ttyarg = "console=ttyS0,9600n8"
  elseif (string.upper(string.sub(dmitable["system.manufacturer"], 1, 7)) == "RADISYS") and (string.find(dmitable["system.product_name"], "ATCA[-]45[05]0")) then
    -- Barwick comes in two known variants so far: a 4-core Nehalem version
    -- (ATCA-4500), and a 6-core Westmere version (ATCA-4550).
    -- Geo/Iris on Barwick only uses ttyS0 at 115.2.
    boardfound = 1
    printf("Detected RadiSys ATCA-45x0 (Barwick) blade\n")
    ttyarg = "console=ttyS0,115200n8"
  elseif (string.upper(dmitable["system.manufacturer"]) == "KONTRON") and (string.upper(dmitable["system.product_name"]) == "KTC5520/EATX") then
    -- Geo/Iris on Sandpiper sets up consoles on both the VGA and on ttyS1.
    -- ttyS1 is the serial-over-LAN port and should be running at 115.2.
    boardfound = 1
    printf("Detected Kontron KTC-5520/EATX motherboard\n")
    ttyarg = "console=ttyS1,115200n8 console=tty0"
  elseif (string.upper(dmitable["system.manufacturer"]) == "EMERSON") and (string.find(dmitable["system.product_name"], "ATCA[-]736[05]")) then
    -- We're aware of both an ATCA-7360 and ATCA-7365 blade from Emerson.
    -- The two are pretty much functionally equivalent as far as we care.
    -- Geo/Iris on Emerson ATCA-736x sets up a serial console on ttyS0.
    boardfound = 1
    printf("Detected Emerson ATCA-736x blade\n")
    ttyarg = "console=ttyS0,9600n8"
  elseif (string.upper(dmitable["system.product_name"]) == "VIRTUALBOX") then
    boardfound = 1
	printf("Detected Virtualbox\n")
	ttyarg = "console=tty0"
  end
  -- TODO: add cases to handle old Geo crap (Kennicott, Damascus, Langley etc)

  if (boardfound == 0) then 
    -- It might have been useful to spit out a DMI dump, but this would
    -- flood the console.  Besides, we already have a separate DMI dump
    -- option in the bootloader.
    printf("Unknown board ('%s' '%s')\n", dmitable["system.manufacturer"], dmitable["system.product_name"])
    syslinux.sleep(5)
  end
else
  printf("No DMI information available\n")
  syslinux.sleep(5)
end

kernargs = "raid=noautodetect initrd=" .. initramfile
kernargs = kernargs .. " ip=off diskless"

if (boardfound ~= 0) then
  -- Append the console argument.
  kernargs = kernargs .. " "
  kernargs = kernargs .. ttyarg
else
  printf("Proceeding with default (VGA console only)\n")
end

-- Append any arguments passed at the boot prompt as well, or within the
-- syslinux config entry.
idx = 1

while (arg[idx]) do
  kernargs = kernargs .. " "
  kernargs = kernargs .. arg[idx]
  idx = idx + 1
end

printf("Loading kernel %s...\n", kernfile)
kernel = syslinux.loadfile(kernfile)
printf("Loading initramfs %s...\n", initramfile)
initrd = syslinux.initramfs_init()
syslinux.initramfs_load_archive(initrd, initramfile)
printf("Running with kernel arguments: %s\n", kernargs)
syslinux.sleep(3)
syslinux.boot_it(kernel, initrd, kernargs)
syslinux.sleep(20)

