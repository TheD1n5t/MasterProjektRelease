# 2025-08-09T12:40:25.160016600
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/commented_final_version.xsa")

status = platform.build()

status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/idk.xsa")

status = platform.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/testest.xsa")

status = platform.build()

