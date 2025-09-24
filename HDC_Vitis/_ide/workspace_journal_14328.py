# 2025-08-15T12:17:41.994103600
import vitis

client = vitis.create_client()
client.set_workspace(path="HDC_Vitis")

platform = client.get_component(name="hdc_platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/testautomate.xsa")

vitis.dispose()

platform = client.get_component(name="hdc_platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/testautomate.xsa")

status = platform.build()

status = platform.build()

comp = client.get_component(name="hdc_application")
comp.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/idktestest.xsa")

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

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/aölskdfjaöklsdjfkla.xsa")

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/aölskdfjaöklsdjfkla.xsa")

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../VITISDEBUGGING/12343325.xsa")

vitis.dispose()

