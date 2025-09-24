# 2025-06-18T16:07:00.151579400
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/debugging_wrapper1.xsa")

status = platform.build()

status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/debugging_wrapper2.xsa")

status = platform.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/design_1_wrapper.xsa")

status = platform.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/design_2_wrapper.xsa")

status = platform.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/design_1_wrapper.xsa")

status = platform.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/design_2_wrapper.xsa")

status = platform.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

