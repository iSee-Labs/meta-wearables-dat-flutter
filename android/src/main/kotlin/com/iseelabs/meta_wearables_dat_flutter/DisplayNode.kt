// Rebuilds the Dart display DSL (JSON maps) into Meta's mwdat-display
// builder scopes. Node shapes match ios/.../DisplayNode.swift.
// Unsupported values are substituted with the closest supported value and
// reported in `warnings`.

package com.iseelabs.meta_wearables_dat_flutter

import android.graphics.BitmapFactory
import com.meta.wearable.dat.display.views.ActionRole
import com.meta.wearable.dat.display.views.Alignment
import com.meta.wearable.dat.display.views.ButtonGroupAlignment
import com.meta.wearable.dat.display.views.ButtonGroupScope
import com.meta.wearable.dat.display.views.ButtonStyle
import com.meta.wearable.dat.display.views.ContentScope
import com.meta.wearable.dat.display.views.CornerRadius
import com.meta.wearable.dat.display.views.Direction
import com.meta.wearable.dat.display.views.FlexBoxBackground
import com.meta.wearable.dat.display.views.FlexBoxScope
import com.meta.wearable.dat.display.views.IconName
import com.meta.wearable.dat.display.views.IconStyle
import com.meta.wearable.dat.display.views.ImageSize
import com.meta.wearable.dat.display.views.TextColor
import com.meta.wearable.dat.display.views.TextStyle

class DisplayNodeBuilder(private val emit: (callbackId: String, type: String) -> Unit) {
    val warnings = mutableListOf<String>()

    /** Builds a non-video root. Any non-flexBox root is wrapped in a column. */
    fun buildRoot(scope: ContentScope, json: Map<*, *>) {
        val root = if (json["type"] == "flexBox") json else mapOf("type" to "flexBox", "children" to listOf(json))
        val padding = Padding.from(root)
        scope.flexBox(
            direction = direction(root["direction"] as? String),
            gap = int(root["spacing"]) ?: 0,
            alignment = alignment(root["alignment"] as? String, "alignment") ?: Alignment.START,
            crossAlignment = alignment(root["crossAlignment"] as? String, "crossAlignment") ?: Alignment.START,
            wrap = root["wrap"] as? Boolean ?: false,
            padding = padding.all,
            paddingTop = padding.top,
            paddingBottom = padding.bottom,
            paddingStart = padding.start,
            paddingEnd = padding.end,
            background = background(root["background"] as? String),
            onClick = (root["onTapId"] as? String)?.let { id -> { emit(id, "tap") } },
        ) {
            noteUnsupported(root)
            children(this, root)
        }
    }

    private fun children(scope: FlexBoxScope, json: Map<*, *>) {
        for (child in json["children"] as? List<*> ?: emptyList<Any>()) {
            (child as? Map<*, *>)?.let { component(scope, it) }
        }
    }

    private fun component(scope: FlexBoxScope, json: Map<*, *>) {
        val grow = float(json["flexGrow"]) ?: 0f
        val shrink = float(json["flexShrink"]) ?: 1f
        val alignSelf = alignment(json["alignSelf"] as? String, "alignSelf")
        when (val type = json["type"]) {
            "flexBox" -> {
                val padding = Padding.from(json)
                scope.flexBox(
                    direction = direction(json["direction"] as? String),
                    gap = int(json["spacing"]) ?: 0,
                    alignment = alignment(json["alignment"] as? String, "alignment") ?: Alignment.START,
                    crossAlignment = alignment(json["crossAlignment"] as? String, "crossAlignment")
                        ?: Alignment.START,
                    wrap = json["wrap"] as? Boolean ?: false,
                    padding = padding.all,
                    paddingTop = padding.top,
                    paddingBottom = padding.bottom,
                    paddingStart = padding.start,
                    paddingEnd = padding.end,
                    background = background(json["background"] as? String),
                    onClick = (json["onTapId"] as? String)?.let { id -> { emit(id, "tap") } },
                    flexGrow = grow,
                    flexShrink = shrink,
                    alignSelf = alignSelf,
                ) {
                    noteUnsupported(json)
                    children(this, json)
                }
            }
            "text" -> scope.text(
                json["text"] as? String ?: "",
                style = when (json["style"]) {
                    "heading" -> TextStyle.HEADING
                    "meta" -> TextStyle.META
                    else -> TextStyle.BODY
                },
                color = if (json["color"] == "secondary") TextColor.SECONDARY else TextColor.PRIMARY,
                flexGrow = grow,
                flexShrink = shrink,
                alignSelf = alignSelf,
            )
            "image" -> {
                val bytes = json["bytes"] as? ByteArray
                val bitmap = bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
                if (bytes != null && bitmap == null) warnings += "Image bytes could not be decoded; falling back to uri."
                scope.image(
                    uri = if (bitmap == null) json["uri"] as? String else null,
                    bitmap = bitmap,
                    sizePreset = if (json["sizePreset"] == "icon") ImageSize.ICON else ImageSize.FILL,
                    cornerRadius = cornerRadius(json["cornerRadius"] as? String),
                    flexGrow = grow,
                    flexShrink = shrink,
                    alignSelf = alignSelf,
                )
            }
            "icon" -> iconName(json["iconName"] as? String)?.let { name ->
                scope.icon(
                    name = name,
                    style = if (json["style"] == "outline") IconStyle.OUTLINE else IconStyle.FILLED,
                    flexGrow = grow,
                    flexShrink = shrink,
                    alignSelf = alignSelf,
                )
            }
            "button" -> scope.button(
                label = json["label"] as? String ?: "",
                style = buttonStyle(json["style"] as? String),
                iconName = iconName(json["iconName"] as? String),
                onClick = (json["onClickId"] as? String)?.let { id -> { emit(id, "click") } },
                flexGrow = grow,
                flexShrink = shrink,
                alignSelf = alignSelf,
                actionRole = if (json["actionRole"] == "primary") ActionRole.PRIMARY else null,
            )
            "buttonGroup" -> scope.buttonGroup(
                alignment = when (json["alignment"]) {
                    "start" -> ButtonGroupAlignment.START
                    "end" -> ButtonGroupAlignment.END
                    else -> ButtonGroupAlignment.CENTER
                },
                flexGrow = grow,
                flexShrink = shrink,
                alignSelf = alignSelf,
            ) {
                for (child in json["buttons"] as? List<*> ?: emptyList<Any>()) {
                    (child as? Map<*, *>)?.let { groupButton(this, it) }
                }
            }
            "videoPlayer" -> warnings += "videoPlayer is only supported as the root view; nested player ignored."
            else -> warnings += "Unknown display node type '$type' ignored."
        }
    }

    private fun groupButton(scope: ButtonGroupScope, json: Map<*, *>) {
        scope.button(
            label = json["label"] as? String ?: "",
            style = buttonStyle(json["style"] as? String),
            iconName = iconName(json["iconName"] as? String),
            onClick = (json["onClickId"] as? String)?.let { id -> { emit(id, "click") } },
            actionRole = if (json["actionRole"] == "primary") ActionRole.PRIMARY else null,
        )
    }

    private fun noteUnsupported(json: Map<*, *>) {
        if (json["cornerRadius"] != null) {
            warnings += "FlexBox cornerRadius is not supported by the DAT Display SDK; ignored."
        }
    }

    // --- Value mapping ------------------------------------------------------------

    private class Padding(val all: Int, val top: Int?, val bottom: Int?, val start: Int?, val end: Int?) {
        companion object {
            fun from(json: Map<*, *>): Padding {
                val insets = json["paddingInsets"] as? Map<*, *>
                return if (insets != null) {
                    Padding(
                        0,
                        (insets["top"] as? Number)?.toInt(),
                        (insets["bottom"] as? Number)?.toInt(),
                        (insets["start"] as? Number)?.toInt(),
                        (insets["end"] as? Number)?.toInt(),
                    )
                } else {
                    Padding((json["padding"] as? Number)?.toInt() ?: 0, null, null, null, null)
                }
            }
        }
    }

    private fun int(value: Any?): Int? = (value as? Number)?.toInt()

    private fun float(value: Any?): Float? = (value as? Number)?.toFloat()

    private fun direction(value: String?): Direction = when (value) {
        "row" -> Direction.ROW
        "rowReverse" -> Direction.ROW_REVERSE
        "columnReverse" -> Direction.COLUMN_REVERSE
        else -> Direction.COLUMN
    }

    private fun alignment(value: String?, field: String): Alignment? = when (value) {
        null -> null
        "start" -> Alignment.START
        "center" -> Alignment.CENTER
        "end" -> Alignment.END
        "stretch" -> Alignment.STRETCH
        else -> {
            warnings += "$field '$value' is not supported by the DAT Display SDK; using center."
            Alignment.CENTER
        }
    }

    private fun background(value: String?): FlexBoxBackground =
        if (value == "card") FlexBoxBackground.CARD else FlexBoxBackground.NONE

    private fun cornerRadius(value: String?): CornerRadius = when (value) {
        "small" -> CornerRadius.SMALL
        "medium" -> CornerRadius.MEDIUM
        "large" -> {
            warnings += "cornerRadius 'large' is not supported by the DAT Display SDK; using medium."
            CornerRadius.MEDIUM
        }
        else -> CornerRadius.NONE
    }

    private fun buttonStyle(value: String?): ButtonStyle = when (value) {
        "secondary" -> ButtonStyle.SECONDARY
        "outline" -> ButtonStyle.OUTLINE
        else -> ButtonStyle.PRIMARY
    }

    private fun iconName(value: String?): IconName? {
        if (value == null) return null
        val name = IconName.values().firstOrNull { it.name == WireCodec.screaming(value) }
            ?: IconName.values().firstOrNull { WireCodec.camel(it.name) == value }
        if (name == null) warnings += "Unknown icon '$value' ignored."
        return name
    }
}
