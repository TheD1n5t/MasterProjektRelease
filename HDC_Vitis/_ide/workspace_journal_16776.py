# 2025-07-29T19:00:48.547934500
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/hopefullygood.xsa")

status = platform.build()

status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/aslökdfjaskdf.xsa")

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/aslökdfjaskdf.xsa")

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/thistimecorrect.xsa")

status = platform.build()

vitis.dispose()

