//Firaxis Change - JW
class MaterialExpressionSmoothstep extends MaterialExpression
	native(Material);

var ExpressionInput	Min;
var ExpressionInput	Max;
var ExpressionInput	Input;

cpptext
{
	virtual INT Compile(FMaterialCompiler* Compiler, INT OutputIndex);
	virtual FString GetCaption() const;

	/**
	 * Replaces references to the passed in expression with references to a different expression or NULL.
	 * @param	OldExpression		Expression to find reference to.
	 * @param	NewExpression		Expression to replace reference with.
	 */
	virtual void SwapReferenceTo(UMaterialExpression* OldExpression,UMaterialExpression* NewExpression = NULL);
}

defaultproperties
{
	MenuCategories(0)="Math"
	MenuCategories(1)="Utility"
}
