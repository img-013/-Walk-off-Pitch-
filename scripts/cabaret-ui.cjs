const fs=require('fs');
for(const [name,fill,edge] of [['normal','#141113','#a5a198'],['hover','#36151e','#f2eadb'],['pressed','#210b12','#ded3bd']]){
 fs.writeFileSync('godot/art/button_'+name+'.svg',`<svg xmlns="http://www.w3.org/2000/svg" width="320" height="80"><path fill="${fill}" stroke="${edge}" stroke-width="2" d="M8 1H312V8H319V72H312V79H8V72H1V8H8Z"/><path fill="none" stroke="${edge}" opacity=".35" d="M12 6H308V74H12Z"/><path fill="${edge}" d="m8 33 4 7-4 7-4-7Zm304 0 4 7-4 7-4-7Z"/></svg>`);
}
let p='godot/resources/tavern_theme.tres',s=fs.readFileSync(p,'utf8'),hdr='',res='';
for(const n of ['normal','hover','pressed']){
 hdr+=`[ext_resource type="Texture2D" path="res://art/button_${n}.svg" id="${n}"]\n`;
 res+=`[sub_resource type="StyleBoxTexture" id="Frame_${n}"]\ntexture = ExtResource("${n}")\ntexture_margin_left = 16.0\ntexture_margin_top = 10.0\ntexture_margin_right = 16.0\ntexture_margin_bottom = 10.0\ncontent_margin_left = 19.0\ncontent_margin_right = 19.0\ncontent_margin_top = 9.0\ncontent_margin_bottom = 9.0\n`;
}
if(!s.includes('Frame_normal')){
 s=s.replace('[gd_resource type="Theme" format=3]','[gd_resource type="Theme" format=3]\n'+hdr).replace('[resource]',res+'[resource]');
 for(const [n,old] of [['normal','Button'],['hover','Hover'],['pressed','Hover']])s=s.replace(`Button/styles/${n} = SubResource("${old}")`,`Button/styles/${n} = SubResource("Frame_${n}")`);
 fs.writeFileSync(p,s);
}
