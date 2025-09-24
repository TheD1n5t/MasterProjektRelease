# 2025-06-25T09:24:22.136117600
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/design_1_wrapper.xsa")

status = platform.build()

status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/design_1_wrapper.xsa")

status = platform.build()

status = platform.build()

comp.build()

vitis.dispose()

