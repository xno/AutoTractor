LJ @..\src\FieldBitmap.luaÑ  ]£	-, 4    X	)  X	
6	  9		6
  9

 )  B
) B		   X	)  X	
6	  9		6
  9

 )  B
) B		   X	+	 =	X	+	 =	)	 =	)	  =	  X	)	 =	X	6	  9		6
  9

6  9 B)  B
) B	=	9	9
!	
	)
 %		
=	9	)
 %		
=		9			 )
 %		
=	
9	"		 		 =	9	"		 		=	9	9
 	
	=	9	9
 	
	=	5	 =	L !                                  bitmap	endZ	endXstartZstartXstepInv	step	size
floorstepLog2sizeIntsizeLog2invertmaxmin	mathÿ										!!!!!!####$$$$$&&&&''''(((())))++,iX  ^iZ  ^iStepLog2  ^iRelX  ^iRelZ  ^iInvert  ^relX \relZ  \self  \ á   .K;4  7  6  9 =6  9 =6  9 =6  9 =6  9 =6  9 =6  9 =6  9 =6  9	 =	6  9
 =
6  4  =6 9 BH6  9<FRû6  L 
pairsbitmap	endZ	endXstartZstartXstepInv	step	sizesizeIntsizeLog2invert	self			


template  /'  i b     *U6  99 9 !"B6  99 9 !"B   J startZstartX	step
floor	mathself  x  z  i j  |   "^)    X9   X+ L )   X9   X+ L + L sizeIntself  i  j   Æ 
Uh)    X)  L XA6  
  X6  9   ) B)    X+ X+ L X0-  9  X-  4  =) )  )ÿÿM6 9-  95 =)	 %		=	BOõ  6 -  9BH9 X9 X)  L X9 X) L 9!FRî)  L 6	 9
) %# B )    X+ X+ L  À
floor	math
pairs
valuebit  insert
tablegetBitHelperConstantsextract
bit32										FieldBitmapTile bitmap  Vi  V"  b 
v   _ h   § 	 %W-  9     B-  9    B  X+ L -  99 8 B)    X+ X+ 9   X  X+ X+ L  ÀinvertbitmapgetBitHelpercheckIndexgetIndexFieldBitmapTile self  &x  &z  &i j  v ret 	 Ê  ]-  9     B-  9   	 B  X+ L 9   X
  X X+ X+ 
  X X6 
  X9 6 99 8)	 
 ) B<X/-  99 8 B)  X&9 9 8) % <X6 
  X9 6 99 8)	  
 ) B<X-  99 8 B)   X9 9 8) %!<+ L  ÀgetBitHelperreplacebitmap
bit32invertcheckIndexgetIndex			










FieldBitmapTile self  ^x  ^z  ^set  ^i Wj  W ^  Õ6   9  -  9 -  9D  À
tilesstepLog2createFieldBitmap
self  o  Ü6  9-  9" B6  9-  9"B I Àfactor2
floor	mathself x  z    
8lã-     B- 9 8  X	
  X
 XK  - 9 4  <- 9 88  X
  X
 XK  - 9 8- 9- 9"- 9"-	 9			 	B<- 9- 9 88   	 BK  ÀÀ  setBitstepLog2factor1getNewTile
tiles










getTile self FieldBitmapTile x  9z  9set  9i 4j  4 Ø  Jó-     B- 9 8  X+ L - 9 88  X+ L - 9- 9 88   D ÀÀ  getBit
tilesgetTile self FieldBitmapTile x  z  i j   ã  s·ý$4   7   6  -  9B Hh6  BHb)
 )  ) M
^ 9	"9	 7 )  7 9	87 )  ) ) MN6 )   X9		  XG9	"9
	 7 6 96  4 6 >6 >BX7X7X56 )    X+ X+ 7 6   X9		  X9	"9
	 7 6 96  4 6 >6 >B6  7 X9		  X9	"9
	 7 6 96  4 6 >6 >B6 7 O²O
¢FRFR6   L  Àbitinsert
tablexstartXinvertnbitmapizstartZstepInv
tiles
pairspoints				


##self k k k_ ht1  he e e_ bt2  b_ _ _j ]O O Oi M   3¦-     B- 9 8  X+ L - 9 88  X+ L + L ÀÀ
tilesgetTile self x  z  i j     
 I°-     B- 9 "- 9 "- 9   	 J ÀÀfactor1getTile self x  z  i j  startX 	startZ length    N»-     B- 9 8  X- 9 4  <- 9 8- 9- 9"- 9"- 9 ,	
 + B<K  ÀÀ  stepLog2factor1getNewTile
tiles
getTile self FieldBitmapTile x  !z  !i j   á 7Ç-  9  ) %7 -  9  ) %7 6 6 96 " B"6 6 96 "B"  J À
floor	mathf2f1stepLog2
ÿself iX   iZ   x z  Î	 /	¦ÐÒ?)  )    	  
  6  9  B 6  9	  B	 6  9  B
 6  9	  B 6  9  B 6  9	  B	 6  9  B
 6  9	  B  !  !6  9  B 6  9	  B	 6  9  B
 6  9	  B -   
 B-  	  B- 9 ) %  ) M@  ) M;+  - 98
  X- 988X+  - 9"- 9") )  )  M$"!""" ")"  )# )$ M""&% &6& 9&&' ( )  * + , - . B&	 & X'
  X&	-& 9&&' ( ) B& & X'O"äOÜOÅOÀ  J ÀÀ  getBitcheckPointInParallelogramFieldBitmapfactor1
tilesstepLog2maxmin	math
						





!!!!""""$%%%%%&&&&&(+++,,,....///00001133333333333334555555555560."!>>>getTile self FieldBitmapTile startWorldX  §startWorldZ  §widthWorldX  §widthWorldZ  §heightWorldX  §heightWorldZ  §area ¥total ¤minX £maxX ¢minZ ¡maxZ  x 2nz lminI PminJ  PmaxI LmaxJ  LstepInv GA A AcurI ?< < <curJ :t2 9startX +startZ (% % %j #  i  ·	 ,£·5     	 6
  9

  B

 6
  9

  B

 6
  9

  B

 6
  9

  B
	
 6
  9

  B

 6
  9

  B

 6
  9

  B

 6
  9

  B
	
  
!
 
 !6  9 
 B 6  9 
 B 6  9  B 6  9  B	 -    B-   	 B- 9 ) %  ) M?  ) M:- 98
  X4- 988
  X.- 9887 - 9"- 9") )  ) M" )  )  )! M"#" 
#6# 9##$
 % &  ' ( ) * + B#	 # X$-# 9#	#6$ %
 & )'  B#OéOáOÆOÁ6
 6 J ÀÀ  
total	areasetBitcheckPointInParallelogramFieldBitmapfactor1t2
tilesstepLog2maxmin	math
						           !!!!!###$$$&&&&'''(((())+++++++++++++,,,,,,,(&444getTile self FieldBitmapTile startWorldX  ¤startWorldZ  ¤widthWorldX  ¤widthWorldZ  ¤heightWorldX  ¤heightWorldZ  ¤minX ¢maxX ¡minZ  maxZ x 2mz kminI OminJ  OmaxI KmaxJ  KstepInv F@ @ @curI >; ; ;curJ 9startX &startZ #     j   i  Â DæÂ6  9  ) B 5 4  ==) %= ) %=6  B X6	  BH9	4
  <
	6		 
 B	H98-  9
 B<FR÷FRî3 3 3 3 3 3	 3
 3 3 3 3 5 ====	=
=====
2  L  ÀcutAreagetAreaTotalCountgetPointcreateOneTilegetTileDimensionstileExistsgetPointsgetBitsetBit             
clone
pairs
table	typefactor2factor1stepLog2
tiles  getNoNil
Utils
                      	 	 	 	 
 
 
              	 	   , 6 _ i t   Ï 	FieldBitmapTile iStepLog2  Etiles  Es >self 3  i t1  
 
 
j t2  clone getTile setBit getBit getPoints tileExists getTileDimensions createOneTile getPoint getAreaTotalCount cutArea      
Ü6   6 9' )  )  )  )  B K  greaterterrainDetailIdg_currentMissionsetDensityCompareParams Â   ¸ã6  96 9  	 
    B6 6 9   	 
  6 96 9B
  J !terrainDetailTypeNumChannels"terrainDetailTypeFirstChannelgetDensityParallelogramterrainDetailIdg_currentMissiongetXZWidthAndHeight
UtilsstartWorldX  startWorldZ  widthWorldX  widthWorldZ  heightWorldX  heightWorldZ  x z  widthX  widthZ  heightX  heightZ  _ area  totalArea   Þ   zì6  9   	 
   B)    X+ X	+ L getAreaTotalFieldBitmapstartWorldX  startWorldZ  widthWorldX  widthWorldZ  heightWorldX  heightWorldZ  area 
totalArea       ô)  ) ) M6
  9

6 9	        B
	)  
 X
+
 L
 Oî+ L terrainDetailIdg_currentMissiongetDensity
UtilsstartWorldX  startWorldZ  widthWorldX  widthWorldZ  heightWorldX  heightWorldZ    channel  D 
   ! !      	J x  z  size  ofs   p    6   6 9' )ÿÿB K  greaterterrainDetailIdg_currentMissionsetDensityCompareParams    .Á!!	!
!! !"	"!"
	"!  X
)   X X)   X X""
!""	
!  X
)   X X)   X X+ L + L  			


px  /pz  /startWorldX  /startWorldZ  /widthWorldX  /widthWorldZ  /heightWorldX  /heightWorldZ  /x2 -z2 ,x3 +z3 *x1 )z1 (bz %bn "az an  Ã   v°-     	 
   B  X) ) J )  ) J ÀiCheckFunction startWorldX  startWorldZ  widthWorldX  widthWorldZ  heightWorldX  heightWorldZ   ÷  $u¬
  X6  9 X6  9   	 
 6  96  96  9 2 X3 6  9  	 
   ,  2  D	 2  K  D	  cleanupAfterIsFieldprepareIsFieldgetAreaTotal"createForFieldAtWorldPositionisFieldFastFieldBitmap	










iX  $iZ  $iStepLog2  $iOverlap  $iCheckFunction  $iYieldCount  $checkFunction   (  Óó½ ,   X6  96  96  9
  X	  X*
 ) X ) %
) %

  
  X""
  X B 6  9     B A )   X
  X B+  )  J 6  9 B 6  9 B	 6 9" B"
6 9"B"
, 4  ) ) 4 4 >>>>9	  B)  )  )  + , 6	 9
8B)   XçUæ4  <6 8BH Ù6" #! B"# " + 9"	# $ B" " X"6" '# B"
  X"V)"  " X"S X"Q
  X"" B"6" 9""+#  "$"$$$$B"
  X"" B"  X"6" '# B"X";  X"6" '# B"X"5!  X"6" '# B"X"/  X"6" '# B"X")8""  X"6" '# B"X""8""  X"6" '# B"X"  X"6" '# B"X"  X"6" '# B"X"	  X"6" '# B"X"	9"	# $ B" " X"6" '# B") 9"# $ B" " X"À9"# $ B"$ # " " 6#  9##$ % & ' B# A" # " 	 X"+ 9"	# $ B"X"¦ X"¤+ 9"	# $ B"9"# $ B"  !
 9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B"  9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B" !
9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B"  9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B"!
!
9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B" !
9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B"!
 9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B"  9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B"  X"©" 6#  9##$ % & ' B# A" )#  #" X"9"# $ B"!
 9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B" 
 9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B" !
9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B"  
9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B"!
!
9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B" 
!
9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B"!
 
9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B" 
 
9"	# $ B" " X"9"	# $ B"6"	 9""8#4$ >$>$B"F R %~   X~
  X B ""J insertcreateOneTilegetTileDimensionstileExists%ERROR: FieldBitmap error code 10$ERROR: FieldBitmap error code 9$ERROR: FieldBitmap error code 8$ERROR: FieldBitmap error code 7$ERROR: FieldBitmap error code 6$ERROR: FieldBitmap error code 5$ERROR: FieldBitmap error code 4$ERROR: FieldBitmap error code 3$ERROR: FieldBitmap error code 2$ERROR: FieldBitmap error code 1
yieldcoroutine%ERROR: FieldBitmap error code 11
printgetBitunpack
pairs	getn
tablesetBit
floor	mathcreategetParallelogramcleanupAfterIsFieldprepareIsFieldgetAreaTotalFieldBitmapÀþÿÛâ±âíèø 				
   #####$$$$$&&&&&&''''''(*++,,,,,,....01234;;;;;;;;<==????@BBBBBCDDDDDDEEEHHHHHHHJJKKNNNNNNNPPQQTTUUUUVVWWWWXXYYYYZZ[[[[\\\]]]]^^^____``aaaabbccccddeeeeffffffgggillllllmmmmmmmnnnnnnnnnnnoopqqqqqrrsttttuuuuvxy{{{{{{{{{{{{{{{{{{{|||||||||||||||||||}}}}}}}}}}}}}}}}}}}~~~~~~~~~~~~~~~~~~~??iX  ÔiZ  ÔiStepLog2  ÔiOverlap  ÔiAreaTotalFunction  ÔiPrepareFunction  ÔiCleanupFunction  ÔiYieldCount  Ôfield Òdone  Òf1  Òf2  Òf3 ½fo1 »fo3  »x +z x1 z1  l1  lists cur nxt  cycle ûcount úsqrm ùskip øa ÷t  ÷Ü Ü Ü_ Ùp  Ùtmp Ü Ñ	  Áã(6   ' B -   9  )
 ) ) , + B 6  6 9 B A 6  6 9 B A 6  6 9 B A 6  6 9 B A 6  6 9 B A 6  6 9	 B A 6  6 9
 B A -  9  *  * + B6  6 -  9  *  * B A  A -  9  ) ) + B6  6 -  9  ) ) B A  A -  9  )
 ) + B6  6 -  9  )
 ) B A  A -  9  * * + B6  6 -  9  * * B A  A 6  6 -  9  ) ) B A  A -  9  ) ) + B6  ' B)ýÿ) ) M)ýÿ) ) M9	 "				9
 "



6  6 	 B' 6 
 B' 6 -  9  	 
 B A &BOæOá6  ' B-  9  ) ) + B6  6 -  9  ) ) B A  A 6  ' BK   À stepInvgetBitsetBit	endZ	endXstartZstartX	stepsizeInt	sizetostringgetNewTileM------------------------------------------------------------------------
printÇ¦Ì					




"""$$$$$$$%%%%%%%%%%'''(FieldBitmapTile tileTest ¶~     i   j x z  Ô
   ØÚ66   ' B *   * 6 9B* 9   B)ýÿ) ) M)ýÿ)	 )
 M"  " 6  6  B' 6  B' 6 9  B A &BOêOå6 9B6  6 9  	 B A  A 6  6 9  	 B A  A 9   + B6  6 9  	 B A  A 6  6 9  	 B A  A 9   B6  6 9  	 B A  A 6  6 9  	 B A  A 6  ' B6  ' B*  * 6 9) B9	 
 B)ýÿ)	 )
 M)ýÿ) ) M" " 6  6  B' 6  B' 6 9  B A &BOêOå6 9)	 B6	  6
 9  B A
  A	 6	  6
 9  B A
  A	 9	
  + B	6	  6
 9  B A
  A	 6	  6
 9  B A
  A	 9	
  B	6	  6
 9  B A
  A	 6	  6
 9  B A
  A	 6	  '
 B	K  getBit tostringsetBitcreateFieldBitmapM------------------------------------------------------------------------
print°¦Àþ								

		    """"########$$%%&&&&&&&&&&&&&&&&&##))))********++++++++-----........////////111122222222333333335556x0 Óz0  Ómap ÐstepInv Ï  i   j x z map2 ©x0 Ahz0  hmap d  i   j x z map2 =   % 3 É4   3 =  3 = 3 = 3 = 3	 = 3 =
 3 = 4  7 6 3 =6 3 =6 3 =6 3 =6 3 =6 3 =6 3 =6 3 =6 3  =6 3" =!3# 3$ 2  K     "createForFieldAtWorldPosition (createForFieldAtWorldPositionSimple checkPointInParallelogram cleanupAfterIsField getParallelogram isField isFieldFast getAreaTotal prepareIsField createFieldBitmap setBit getBit getBitHelper checkIndex getIndex 
clone getNewTile 6 	 P ; Y U b ^  h   ¸  ½ ½ Â ×Â ÜÞÜãçãìïìôûô  	',8,=Ý=CCCFieldBitmapTile 2unitTest1 /unitTest2   