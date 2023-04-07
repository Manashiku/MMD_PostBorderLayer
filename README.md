# MMD_PostBorderLayer
Post fx for MMD to apply a border and/or layer it behind a foreground object
***
# How to use:
### for MikuMikuDance :
>0. Set up your scene before hand
>1. Load in `post border.x` and make sure it is the last item in the accessories drawing order list (Background>Accessory Edit)
>2. Load the `controller.pmx`
>3. Apply the `depth_render_fg.fx` to the foreground objects you want to pop out above the border
>4. Play around with the settings in the controller morph sliders
>5. done!

### for MikuMikuMoving : 
>0. Set up your scene before hand
>1. Load in `post border.fx` and make sure it is the last item in the accessories drawing order list (Background>Accessory Edit)
>2. Load the `controller.pmx`
>3. With the `post border.fx` selected under the effect tab in the bottom bar of the program, Apply the `depth_render_fg.fx` to the foreground objects you want to pop out above the border in the depth_texture tab 
>4. Play around with the settings in the controller morph sliders
>5. done!
