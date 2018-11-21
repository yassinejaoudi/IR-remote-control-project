transcript off
vcom RC_receiver.vhd
vcom test_RC_receiver.vhd

vsim test_RC_receiver
add wave sim:/test_RC_receiver/dev_to_test/*
 
run 5120 ns